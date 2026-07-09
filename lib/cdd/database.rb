# frozen_string_literal: true

require "forwardable"

module Cdd
  class Database
    Dictionary = Struct.new(
      :parcel_id, :source_language, :translation_languages, :meta_class_irdis,
      keyword_init: true,
    )

    FORCED_META_CLASSES = %w[MDC_C002 MDC_C003].freeze
    PARCEL_ID_PATTERN = /\A[A-Z0-9-]+\z/.freeze

    ENTITY_CLASSES_BY_TYPE = {
      class:        Cdd::Klass,
      property:     Cdd::Property,
      unit:         Cdd::Unit,
      value_list:   Cdd::ValueList,
      value_term:   Cdd::ValueTerm,
      relation:     Cdd::Relation,
      view_control: Cdd::ViewControl,
    }.freeze

    attr_reader :workbooks, :unresolved_refs, :alias_table

    def self.load(path)
      Cdd::Reader.load_database(path)
    end

    def self.load_workbook(path)
      Cdd::Parcel::WorkbookReader.new(path).load_into(new)
    end

    def self.load_flat_dir(path)
      Cdd::Parcel::FlatDirReader.new(path).load_into(new)
    end

    def self.load_sharded_dir(path)
      Cdd::Parcel::ShardedDirReader.new(path).load_into(new)
    end

    def initialize
      @entities_by_irdi = {}
      @entities_by_code = Hash.new { |h, k| h[k] = [] }
      @entities_by_type = Hash.new { |h, k| h[k] = [] }
      @workbooks = []
      @unresolved_refs = []
      @class_by_property_irdi = nil
      @symbol_table = {}
      @alias_table = Cdd::AliasTable.new(defaults: true)
      @entity_sources = {}
    end

    def add_workbook(workbook)
      @workbooks << workbook
      parcel_id = workbook.parcel_id
      workbook.each_sheet do |sheet|
        next unless sheet.type && sheet.rows.any?
        type = sheet.type
        entity_class = ENTITY_CLASSES_BY_TYPE[type]
        raise "Unknown entity type #{type.inspect} for sheet #{sheet.name.inspect}" unless entity_class

        sheet.rows.each do |row|
          entity = entity_class.from_row(
            row,
            schema: sheet.schema,
            meta_class_irdi: sheet.meta_class_irdi,
          )
          add_entity(entity)
          if parcel_id && entity.irdi
            prev = @entity_sources[entity.irdi]
            @entity_sources[entity.irdi] = prev.nil? ? parcel_id : prev
          end
        end
      end
      self
    end

    def add_entity(entity)
      irdi = entity.irdi
      if irdi.nil?
        @unresolved_refs << [nil, entity]
        return self
      end

      if @entities_by_irdi.key?(irdi)
        existing = @entities_by_irdi[irdi]
        return self if existing.properties == entity.properties
        warn "Duplicate IRDI #{irdi} — overwriting"
      end

      @entities_by_irdi[irdi] = entity
      @entities_by_code[irdi.code] << entity if irdi.code
      @entities_by_type[entity.type] << entity if entity.type

      register_entity_symbols(entity)

      if entity.is_a?(Cdd::Klass)
        entity.attach_database(self)
      end
      self
    end

    def register_symbol(name, entity)
      bind_symbol(name, entity)
    end

    def register_entity_symbols(entity)
      name = entity.is_a?(Cdd::Entity) ? entity.preferred_name : nil
      bind_symbol(name, entity) if name
      code = entity.code
      bind_symbol(code, entity) if code
      self
    end

    def resolve_reference(ref)
      return nil if ref.nil?
      return ref if ref.is_a?(Cdd::Entity)

      key = ref.to_s.strip
      return nil if key.empty?

      if key.include?("/") || key.include?("#")
        irdi = Cdd::IRDI.parse(key)
        return find(irdi)
      end

      entity = @symbol_table[key]
      return entity if entity

      by_code = find_by_code(key)
      return by_code if by_code

      irdi = Cdd::IRDI.parse(key)
      irdi ? find(irdi) : nil
    end

    def finalize!
      normalize_reference_collections!
      link_class_hierarchy!
      link_property_classes!
      link_value_lists!
      rebuild_symbol_table!
      self
    end

    def normalize_reference_collections!
      set_property_ids = Cdd::PropertyIds::REGISTRY.select { |_, e| e.value_kind == :set_of_refs }.keys
      entities.each do |entity|
        set_property_ids.each do |pid|
          val = entity.properties[pid]
          next if val.nil?
          s = val.to_s.strip
          next unless s.start_with?("(") && s.end_with?(")")
          inner = s[1..-2]
          elements = inner.split(",").map(&:strip).reject(&:empty?)
          entity.properties[pid] = "{#{elements.join(',')}}"
        end
      end
      self
    end

    def find(irdi)
      return nil if irdi.nil?
      key = Cdd::IRDI === irdi ? irdi : Cdd::IRDI.parse(irdi)
      return nil unless key
      @entities_by_irdi[key]
    end

    def find_by_code(code)
      matches = @entities_by_code[code.to_s]
      return nil if matches.empty?
      matches.first
    end

    def find_all_by_code(code)
      @entities_by_code[code.to_s].dup
    end

    def find_by_name(name, type: nil, lang: :en)
      pools = type ? [@entities_by_type[type]].compact : @entities_by_type.values
      pools.each do |pool|
        hit = pool.find { |e| e.preferred_name(lang).to_s.casecmp(name.to_s).zero? }
        return hit if hit
      end
      nil
    end

    def classes        ; @entities_by_type[:class]        || [] ; end
    def properties     ; @entities_by_type[:property]     || [] ; end
    def units          ; @entities_by_type[:unit]         || [] ; end
    def value_lists    ; @entities_by_type[:value_list]   || [] ; end
    def value_terms    ; @entities_by_type[:value_term]   || [] ; end
    def relations      ; @entities_by_type[:relation]     || [] ; end
    def view_controls  ; @entities_by_type[:view_control] || [] ; end

    def entities_of_type(type)
      @entities_by_type[type.to_sym] || []
    end

    def entities
      @entities_by_irdi.values
    end

    def count(type = nil)
      type ? (@entities_by_type[type] || []).size : @entities_by_irdi.size
    end

    def root_classes
      classes.select { |c| c.parent_irdi.nil? }
    end

    def class_tree(fields: Cdd::ClassTree::DEFAULT_FIELDS)
      Cdd::ClassTree.new(self, fields: fields)
    end

    def effective_properties
      @effective_properties ||= Cdd::EffectiveProperties.new(self)
    end

    def composition_tree(klass, max_depth: 10)
      Cdd::CompositionTree.new(self).for(klass, max_depth: max_depth)
    end

    def relation_tree(root = nil, max_depth: 10)
      Cdd::RelationTree.new(self).for(root, max_depth: max_depth)
    end

    def add_dictionary(dict)
      validate_parcel_id!(dict.parcel_id)
      source_language = dict.source_language || "en"
      translation_languages = Array(dict.translation_languages)
      meta_irdis = normalize_meta_class_irdis(dict.meta_class_irdis)

      sheets = meta_irdis.map do |meta_irdi|
        Cdd::Parcel::Sheet.scaffold(
          meta_class_irdi: meta_irdi,
          parcel_id: dict.parcel_id,
          source_language: source_language,
          translation_languages: translation_languages,
        )
      end

      project = Cdd::Parcel::Workbook::ProjectInfo.new(
        project_id: dict.parcel_id,
        parcel_id:  dict.parcel_id,
        multi_language: translation_languages.join(","),
        base_language: source_language,
      )
      sheetmap = build_sheetmap_for(dict.parcel_id, sheets)
      workbook = Cdd::Parcel::Workbook.new(
        sheets: sheets, sheetmap: sheetmap, project: project,
      )
      @workbooks << workbook
      workbook
    end

    def drop_dictionary(parcel_id)
      matching = @workbooks.select { |wb| wb.parcel_id == parcel_id }
      raise ArgumentError, "no dictionary with parcel_id #{parcel_id.inspect}" if matching.empty?

      irdis_to_drop = @entity_sources.select { |_, pid| pid == parcel_id }.keys
      irdis_to_drop.each do |irdi|
        remove_entity_by_irdi!(irdi)
        @entity_sources.delete(irdi)
      end
      @workbooks.reject! { |wb| wb.parcel_id == parcel_id }
      self
    end

    def register_external_sheet(sheet, parcel_id:)
      validate_parcel_id!(parcel_id)
      wb = @workbooks.find { |w| w.parcel_id == parcel_id }
      if wb.nil?
        project = Cdd::Parcel::Workbook::ProjectInfo.new(
          project_id: parcel_id, parcel_id: parcel_id,
          multi_language: "", base_language: "en",
        )
        wb = Cdd::Parcel::Workbook.new(sheets: [], sheetmap: [], project: project)
        @workbooks << wb
      end
      wb.register_sheet(sheet)
      self
    end

    def dictionaries
      @workbooks.map do |wb|
        Dictionary.new(
          parcel_id: wb.parcel_id,
          source_language: wb.base_language,
          translation_languages: parse_translation_languages(wb),
          meta_class_irdis: wb.sheets.map(&:meta_class_irdi).compact.uniq,
        )
      end
    end

    def rename_entity(old_code, new_code)
      old_code_s = old_code.to_s
      new_code_s = new_code.to_s
      return self if old_code_s == new_code_s

      target = find_by_code(old_code_s)
      return self unless target

      clash = find_by_code(new_code_s)
      if clash && clash.irdi != target.irdi
        warn "Cannot rename #{old_code_s} → #{new_code_s}: target code already in use by #{clash.irdi}"
        return self
      end

      old_irdi = target.irdi
      new_irdi = old_irdi.with_code(new_code_s)

      @entities_by_irdi.delete(old_irdi)
      @entities_by_code[old_code_s].delete(target)

      ref_property_ids = Cdd::PropertyIds::REGISTRY.select do |_, e|
        REFERENCE_VALUE_KINDS.include?(e.value_kind)
      end.keys

      entities.each do |entity|
        rewrite_back_references!(entity, old_irdi, new_irdi, ref_property_ids)
      end

      code_pid = target.class.default_code_property_id(target.meta_class_irdi)
      target.replace_code_value!(code_pid, new_code_s)
      target.replace_irdi!(new_irdi)

      @entities_by_irdi[new_irdi] = target
      @entities_by_code[new_code_s] << target

      rebuild_symbol_table!
      self
    end

    def apply_view_control(klass, view_control)
      properties = effective_properties.for(klass).to_a
      return properties unless view_control.is_a?(Cdd::ViewControl)

      controlled = view_control.controlled_class_irdis
      k = klass.is_a?(Cdd::Klass) ? klass : find(klass)
      return properties unless k && controlled.include?(k.irdi)

      shown = view_control.shown_property_irdis
      lookup = properties.each_with_object({}) { |p, h| h[p.irdi] = p }
      shown.filter_map { |irdi| lookup[irdi] }
    end

    def properties_of(klass)
      k = klass.is_a?(Cdd::Klass) ? klass : find(klass)
      return [] unless k.is_a?(Cdd::Klass)
      k.properties_on_class(self)
    end

    def classes_with_property(property)
      irdi = property.is_a?(Cdd::Property) ? property.irdi : Cdd::IRDI.parse(property)
      return [] unless irdi
      @class_by_property_irdi&.fetch(irdi, []) || []
    end

    def value_list_of(property)
      return nil unless property.is_a?(Cdd::Property)

      relations.each do |r|
        next unless r.predication?
        next unless r.domain_irdis.include?(property.irdi)
        vl = r.codomain_irdi && find(r.codomain_irdi)
        return vl if vl.is_a?(Cdd::ValueList)
      end

      return nil unless property.enum?
      identifier = value_list_identifier_of(property)
      return nil unless identifier
      vl = resolve_reference(identifier)
      vl if vl.is_a?(Cdd::ValueList)
    end

    def value_list_identifier_of(property)
      case property.parsed_data_type
      when Cdd::DataType::EnumStringType, Cdd::DataType::EnumReferenceType
        property.parsed_data_type.value_list_identifier
      end
    end

    def terms_of(value_list)
      return [] if value_list.nil?
      value_list.term_irdis.map { |i| find(i) }.compact
    end

    def relations_for(domain: nil, codomain: nil)
      relations.select do |r|
        (domain.nil?  || r.domain_irdis.include?(domain.is_a?(Cdd::Entity) ? domain.irdi : domain)) &&
          (codomain.nil? || r.codomain_irdi == (codomain.is_a?(Cdd::Entity) ? codomain.irdi : codomain))
      end
    end

    def functions_involving(property)
      irdi = property.is_a?(Cdd::Property) ? property.irdi : Cdd::IRDI.parse(property)
      return [] unless irdi
      relations.select do |r|
        r.function? && (r.domain_irdis.include?(irdi) || r.codomain_irdi == irdi)
      end
    end

    def merge(other)
      raise TypeError, "merge expects a Cdd::Database" unless other.is_a?(Cdd::Database)
      other.entities.each { |e| add_entity(e) }
      finalize!
      self
    end

    # Applies a Parcel change request (CR) to this database.
    #
    # +cr+ is a +Cdd::Database+ whose entities represent the
    # additions and updates to apply. +removals:+ is an Array of
    # IRDIs (Strings or +Cdd::IRDI+ instances) identifying entities
    # to delete from this database.
    #
    # Unlike +#merge+, which is purely additive, +#apply_change_request+
    # honors an explicit removal list. The CR's own entities are
    # upserted first (so an update-then-remove ordering resolves to
    # remove), then removals are applied.
    #
    # Returns +self+ for chaining.
    def apply_change_request(cr, removals: [])
      raise TypeError, "apply_change_request expects a Cdd::Database" unless cr.is_a?(Cdd::Database)
      cr.entities.each { |e| add_entity(e) }
      Array(removals).each { |r| remove_by_irdi(r) }
      finalize!
      self
    end

    def remove_by_irdi(ref)
      irdi = ref.is_a?(Cdd::IRDI) ? ref : Cdd::IRDI.parse(ref.to_s)
      return unless irdi
      remove_entity_by_irdi!(irdi)
      @entity_sources.delete(irdi)
      self
    end

    def each(&block)
      @entities_by_irdi.each_value(&block)
    end

    include Enumerable

    def semantically_equal?(other)
      return false unless other.is_a?(Cdd::Database)
      return false unless entities.size == other.entities.size
      entities.all? do |e|
        oe = other.find(e.irdi)
        oe && e.type == oe.type && e.properties == oe.properties
      end
    end

    def to_s
      "#<#{self.class.name} classes=#{classes.size} properties=#{properties.size} " \
        "units=#{units.size} value_lists=#{value_lists.size} value_terms=#{value_terms.size} " \
        "relations=#{relations.size}>"
    end

    alias_method :inspect, :to_s

    private

    REFERENCE_VALUE_KINDS = %i[identifier_ref set_of_refs class_ref].freeze

    def rewrite_back_references!(entity, old_irdi, new_irdi, ref_property_ids)
      ref_property_ids.each do |pid|
        raw = entity.properties[pid]
        next if raw.nil?
        entry = Cdd::PropertyIds::REGISTRY[pid]
        case entry.value_kind
        when :identifier_ref
          parsed = Cdd::IRDI.parse(raw.to_s)
          next unless parsed == old_irdi
          entity.properties[pid] = new_irdi.to_s
        when :set_of_refs
          elements = Cdd::ParseHelpers.parse_irdi_list(raw)
          next if elements.empty?
          mapped = elements.map { |i| i == old_irdi ? new_irdi : i }
          entity.properties[pid] = "{#{mapped.map(&:to_s).join(',')}}"
        when :class_ref
          entity.properties[pid] = substitute_class_ref_value(raw.to_s, old_irdi, new_irdi)
        end
      end
    end

    def substitute_class_ref_value(raw, old_irdi, new_irdi)
      out = raw.sub(old_irdi.to_s, new_irdi.to_s)
      return out if old_irdi.code.nil? || old_irdi.code == new_irdi.code
      out.sub(old_irdi.code, new_irdi.code)
    end

    def bind_symbol(name, entity)
      key = name.to_s
      existing = @symbol_table[key]
      if existing && existing.irdi != entity.irdi
        warn "Symbol #{key.inspect} already bound to #{existing.irdi}; ignoring rebind to #{entity.irdi}"
        return self
      end
      @symbol_table[key] = entity
      self
    end
    def rebuild_symbol_table!
      entities.each { |e| register_entity_symbols(e) }
    end

    def link_class_hierarchy!
      classes.each do |klass|
        next if klass.parent_irdi
        parent_id = klass.parent_property_id || Cdd::PropertyIds::MDC_P010
        parent_raw = klass.properties[parent_id]
        next if parent_raw.nil? || parent_raw.to_s.strip.empty?
        target = resolve_reference(parent_raw)
        next unless target
        klass.parent_irdi = target.irdi
        target.children << klass unless target.children.include?(klass)
      end
    end

    def link_property_classes!
      @class_by_property_irdi = Hash.new { |h, k| h[k] = [] }
      relations.each do |r|
        next unless r.predication? || r.function?
        next if r.domain_irdis.empty?
        next unless r.codomain_irdi
        r.domain_irdis.each do |d|
          next unless d
          src = find(d)
          dst = find(r.codomain_irdi)
          next unless src && dst

          if src.is_a?(Cdd::Klass) && dst.is_a?(Cdd::Property)
            src.declared_property_irdis << dst.irdi unless src.declared_property_irdis.include?(dst.irdi)
            @class_by_property_irdi[dst.irdi] << src unless @class_by_property_irdi[dst.irdi].include?(src)
          elsif src.is_a?(Cdd::Property) && dst.is_a?(Cdd::Klass)
            dst.declared_property_irdis << src.irdi unless dst.declared_property_irdis.include?(src.irdi)
            @class_by_property_irdi[src.irdi] << dst unless @class_by_property_irdi[src.irdi].include?(dst)
          end
        end
      end
    end

    def link_value_lists!
      properties.each do |prop|
        next unless prop.enum?
        identifier = value_list_identifier_of(prop)
        vl_irdi = identifier && resolve_reference(identifier)&.irdi
        next unless vl_irdi
        vl = find(vl_irdi)
        next unless vl.is_a?(Cdd::ValueList)
        @class_by_property_irdi[prop.irdi] << vl unless @class_by_property_irdi[prop.irdi].include?(vl)
      end
    end

    def validate_parcel_id!(parcel_id)
      unless parcel_id.is_a?(String) && parcel_id.match?(PARCEL_ID_PATTERN)
        raise ArgumentError, "invalid parcel_id: #{parcel_id.inspect}"
      end
    end

    def normalize_meta_class_irdis(raw)
      codes = Array(raw).map { |v| v.to_s.split("#").last }
      FORCED_META_CLASSES.each { |c| codes << c unless codes.include?(c) }
      codes.uniq
    end

    def build_sheetmap_for(parcel_id, sheets)
      entries = [
        Cdd::Parcel::Workbook::SheetMapEntry.new(
          project_id: parcel_id, parcel_id: parcel_id, class_irdi: nil,
          content_no: 0, sheet_no: 2, sheet_name: "pcls_LOCAL",
          type: "PARCEL_LIST", target: "",
        ),
      ]
      sheets.each_with_index do |sheet, idx|
        entries << Cdd::Parcel::Workbook::SheetMapEntry.new(
          project_id: parcel_id, parcel_id: parcel_id,
          class_irdi: sheet.meta_class_irdi,
          content_no: 0, sheet_no: idx + 3,
          sheet_name: sheet.name,
          type: parcel_type_label_for(Cdd::MetaClasses.type_for(sheet.meta_class_code)),
          target: "",
        )
      end
      entries
    end

    def parse_translation_languages(workbook)
      multi = workbook.project&.multi_language.to_s
      multi.split(",").map(&:strip).reject(&:empty?)
    end

    def parcel_type_label_for(type)
      return nil if type.nil?
      {
        class:        "CLASS",
        property:     "PROPERTY",
        value_list:   "ENUM",
        value_term:   "TERMINOLOGY",
        unit:         "UoM",
        relation:     "RELATION",
        view_control: "VIEWCONTROL",
      }.fetch(type, type.to_s.upcase)
    end

    def remove_entity_by_irdi!(irdi)
      entity = @entities_by_irdi.delete(irdi)
      return unless entity
      if entity.code
        list = @entities_by_code[entity.code]
        list.delete(entity)
        @entities_by_code.delete(entity.code) if list.empty?
      end
      if entity.type
        @entities_by_type[entity.type].delete(entity)
      end
      @symbol_table.delete_if { |_, e| e.equal?(entity) }
    end
  end
end
