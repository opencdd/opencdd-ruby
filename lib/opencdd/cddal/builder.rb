# frozen_string_literal: true

require "set"

module Opencdd
  module Cddal
    # Source location attached to every entity created from CDDAL
    # for diagnostics (validator messages, error attribution,
    # cross-file navigation in the editor).
    SourceLocation = Struct.new(:file, :line, keyword_init: true) do
      def to_s
        "#{file}:#{line || '?'}"
      end
    end

    # Builds a +Opencdd::Database+ from a parsed CDDAL AST. Owns the
    # module/import pipeline: resolves specifiers via the configured
    # +Resolver+, fetches sources via the +Fetcher+, recursively
    # builds imported documents into the same database, tracks the
    # dependency graph for cycle detection, and applies bare,
    # qualified, and selective import scoping rules.
    class Builder
      attr_reader :database, :alias_table, :symbol_table, :meta_class_overrides,
                  :source_file, :loaded_modules

      def initialize(database = nil, resolver: nil, source_file: nil,
                     loaded_modules: nil, loading_stack: nil)
        @database = database || Opencdd::Database.new
        @resolver = resolver || Opencdd::Cddal.default_resolver
        @source_file = source_file
        @loaded_modules = loaded_modules || {}
        @loading_stack = loading_stack || []
        @alias_table = Opencdd::AliasTable.new(defaults: true)
        @symbol_table = {}
        @qualified_table = {} # "qualifier.name" => entity (qualified imports)
        @instance_decls = []
        @meta_class_overrides = {}
      end

      def build(document_or_declarations)
        document = wrap_document(document_or_declarations)
        apply_alias_declarations(document)
        apply_meta_class_declarations(document)
        apply_import_declarations(document)
        register_instance_symbols(document)
        instantiate_entities(document)
        resolve_property_references(document)
        # Linking (parent/child, declared_property_irdis, value lists,
        # symbol table) lives in Database.finalize! — single source
        # of truth for entity-graph invariants. Builder used to
        # duplicate link_class_hierarchy / link_property_classes;
        # those were folded into Database#link_property_classes!
        # (which now runs both relation-based and definition_class-
        # based strategies).
        @database.finalize!
        @database
      end

      # Resolve +specifier+ and return its source text without
      # building it into the database. Used by the validator and
      # by diagnostics that want to peek at imports.
      def peek_import(specifier)
        @resolver.resolve(specifier, importing_file: @source_file)
      end

      private

      def wrap_document(document_or_declarations)
        return document_or_declarations if document_or_declarations.is_a?(AST::Document)
        AST::Document.new(declarations: Array(document_or_declarations))
      end

      def apply_alias_declarations(document)
        document.alias_declarations.each do |decl|
          @alias_table.declare(decl.alias_name, decl.property_id)
        end
      end

      def apply_meta_class_declarations(document)
        document.meta_class_declarations.each do |decl|
          meta = Opencdd::MetaClass::MetaClasses.for(decl.irdi)
          extension = Opencdd::MetaClass.new(
            irdi: decl.irdi,
            name: meta&.name || decl.irdi,
            entity_class: meta&.entity_class,
            allowed_property_ids: decl.property_ids.map { |id| resolve_property_id(id) },
          )
          @meta_class_overrides[decl.irdi] = extension
          Opencdd::MetaClass::MetaClasses.register(extension)
        end
      end

      # ── Module/import pipeline ─────────────────────────────────
      #
      # Three import kinds share the same resolution + cycle-check
      # + recursive-build core. They differ only in how the imported
      # module's named declarations are surfaced in the parent
      # document's symbol table:
      #
      #   bare       — every name from the target is in scope.
      #   qualified  — name accessible as "<qualifier>.<name>".
      #   selective  — only the listed names are in scope, each
      #                optionally renamed via "as".
      #
      # All entities from the imported module are added to the parent
      # Database regardless of import kind — IRDI references remain
      # resolvable. The import kind controls only which symbolic
      # names are accessible without qualification.

      def apply_import_declarations(document)
        document.import_declarations.each { |decl| process_import(decl) }
      end

      def process_import(decl)
        canonical, source = resolve_specifier(decl.specifier)
        # Resolution may return [nil, nil] in non-strict mode when
        # the specifier points at an unreachable URL or a missing
        # file. Skip the import with a warning — preserves the
        # graceful-degradation behavior CDDAL authors expect for
        # cross-dictionary URLs.
        return if canonical.nil?
        return if @loaded_modules.key?(canonical)
        check_cycle!(canonical, decl.specifier)

        @loading_stack.push(canonical)
        sub_doc = Opencdd::Cddal::Parser.parse(source)
        Builder.new(@database, resolver: @resolver, source_file: canonical,
                                loaded_modules: @loaded_modules,
                                loading_stack: @loading_stack)
          .build(sub_doc)
        @loading_stack.pop
        @loaded_modules[canonical] = true

        # Symbol scoping is applied AFTER the sub-document is built,
        # so the named entities exist in @database by the time we
        # look them up.
        apply_import_scope(decl, canonical)
      end

      def resolve_specifier(specifier)
        @resolver.resolve(specifier, importing_file: @source_file)
      end

      def check_cycle!(canonical, specifier)
        return unless @loading_stack.include?(canonical)
        cycle = @loading_stack.dup
        cycle << canonical
        raise Opencdd::Cddal::ImportError,
              "circular CDDAL import detected: #{cycle.join(' → ')} " \
              "(originally imported as #{specifier.inspect})"
      end

      def apply_import_scope(decl, _canonical)
        case decl.kind
        when :bare
          # Nothing to do — bare imports leave the sub-document's
          # names in the shared @database symbol table.
        when :qualified
          register_qualified_symbols(decl.qualifier)
        when :selective
          register_selective_symbols(decl.imported_names)
        end
      end

      def register_qualified_symbols(qualifier)
        @database.entities.each do |entity|
          name = entity_alias_name(entity)
          next unless name
          qualified = "#{qualifier}.#{name}"
          @qualified_table[qualified] = entity
          @database.register_symbol(qualified, entity)
        end
      end

      def register_selective_symbols(imported_names)
        imported_names.each do |imported|
          entity = @database.resolve_reference(imported.name)
          next unless entity
          # Register in the parent Database's symbol table so the
          # renamed name resolves during link phase.
          @database.register_symbol(imported.local_name, entity)
        end
      end

      def entity_alias_name(entity)
        code = entity.code
        return code if code && !code.empty?
        entity.preferred_name.to_s
      end

      def register_instance_symbols(document)
        document.instance_declarations.each do |decl|
          @instance_decls << decl
          register_symbol_name(decl.name, decl) if decl.name
        end
      end

      def register_symbol_name(name, decl)
        key = name.to_s
        if @symbol_table.key?(key) && @symbol_table[key] != decl
          warn "Symbol #{key.inspect} already declared; ignoring redefinition"
          return
        end
        @symbol_table[key] = decl
      end

      def instantiate_entities(document)
        @instance_decls.each do |decl|
          entity = build_entity(decl)
          next unless entity
          attach_source_location(entity, decl)
          @database.add_entity(entity)
          @database.register_symbol(decl.name, entity) if decl.name
        end
      end

      def attach_source_location(entity, decl)
        loc = SourceLocation.new(file: @source_file, line: decl.line)
        entity.attach_source_location(loc)
      end

      def build_entity(decl)
        meta_class = resolve_meta_class(decl.meta_class_ref)
        return nil unless meta_class && meta_class.entity_class

        properties = build_properties(decl)
        irdi = extract_irdi(properties)
        meta_irdi = Opencdd::IRDI.parse(meta_class.irdi)

        meta_class.entity_class.new(
          irdi: irdi,
          properties: properties,
          schema: nil,
          meta_class_irdi: meta_irdi,
        )
      end

      def resolve_meta_class(ref)
        return nil unless ref
        return @meta_class_overrides[ref] if @meta_class_overrides.key?(ref)
        return Opencdd::MetaClass::MetaClasses.for(ref) if ref.to_s.match?(/\AMDC_C\d+\z/) || ref.to_s.match?(/\AEXT_C\d+\z/)

        canonical = resolve_property_id(ref)
        Opencdd::MetaClass::MetaClasses.for(canonical) if canonical
      end

      def build_properties(decl)
        # Resolve the meta-class once so per-assignment code-alias
        # resolution can be context-aware. Without this, a CDDAL
        # `code: AAAP001` on a Property stores the value under
        # MDC_P001_5 (the Class code) — Parcel readers look for
        # MDC_P001_6 (the Property code) and miss it, dropping the
        # entity on round-trip.
        meta_class_code = resolve_meta_class_code(decl.meta_class_ref)
        canonical_code_pid = meta_class_code &&
          Opencdd::MetaClasses.code_property_id_for(meta_class_code)

        props = {}
        decl.assignments.each do |assignment|
          property_id = resolve_property_id(
            assignment.identifier,
            canonical_code_pid: canonical_code_pid,
          )
          key = compose_property_key(property_id, assignment.language_tag)
          value = serialize_value(assignment.value, property_id)
          props[key] = merge_property_value(props[key], value)
        end
        props
      end

      def compose_property_key(property_id, language_tag)
        return property_id unless language_tag
        "#{property_id}.#{language_tag}"
      end

      def merge_property_value(existing, new_value)
        if existing.nil?
          new_value
        elsif existing.is_a?(Array) || new_value.is_a?(Array)
          Array(existing) + Array(new_value)
        else
          new_value
        end
      end

      def resolve_meta_class_code(ref)
        return nil unless ref
        meta_class = resolve_meta_class(ref)
        meta_class&.irdi
      end

      # Resolve an alias or property name to its canonical property ID.
      #
      # When +canonical_code_pid:+ is supplied (the meta-class's
      # canonical code property), and the resolved ID is one of the
      # MDC_P001_X code variants for a *different* meta-class,
      # we redirect to the canonical. This makes the CDDAL `code`
      # alias context-aware: writing `code: AAA001` on a Property
      # stores the value under MDC_P001_6, not MDC_P001_5.
      def resolve_property_id(name, canonical_code_pid: nil)
        s = name.to_s
        return s if s.match?(/\AMDC_P\d+/) || s.match?(/\AEXT_P\d+/)
        resolved = @alias_table.resolve(s) || s
        return resolved unless canonical_code_pid
        return resolved if resolved == canonical_code_pid
        # Only redirect when the resolved ID is one of the per-meta-class
        # code variants AND we have a different canonical in scope.
        if CODE_VARIANT_IDS.include?(resolved)
          canonical_code_pid
        else
          resolved
        end
      end

      # All per-meta-class code property IDs. Used by
      # +resolve_property_id+ to recognize code aliases that should
      # be redirected to the meta-class's canonical code property.
      CODE_VARIANT_IDS = %w[
        MDC_P001 MDC_P001_1 MDC_P001_2 MDC_P001_5 MDC_P001_6 MDC_P001_7
        MDC_P001_8 MDC_P001_10 MDC_P001_11 MDC_P001_12 MDC_P001_13
        EXT_P001
      ].freeze
      private_constant :CODE_VARIANT_IDS

      def serialize_value(value, property_id)
        Opencdd::Cddal::ValueSerializer.serialize(value, property_id)
      end

      def extract_irdi(properties)
        raw = properties[Opencdd::PropertyIds::MDC_P001_5] || properties[Opencdd::PropertyIds::MDC_P001_6] ||
              properties[Opencdd::PropertyIds::MDC_P001_10] || properties[Opencdd::PropertyIds::MDC_P001_11] ||
              properties[Opencdd::PropertyIds::MDC_P001_12] || properties[Opencdd::PropertyIds::MDC_P001_13]
        return nil unless raw
        Opencdd::IRDI.parse(raw.to_s)
      end

      def resolve_property_references(document)
        reference_kinds = %i[identifier_ref set_of_refs class_ref].freeze
        reference_property_ids = Set.new(
          Opencdd::PropertyIds::REGISTRY.select { |_, e| reference_kinds.include?(e.value_kind) }.keys
        )
        @database.entities.each do |entity|
          properties = entity.properties
          properties.each do |key, value|
            base = key.to_s.sub(/\.\w+\z/, "")
            next unless reference_property_ids.include?(base)
            next if value.nil? || value.to_s.strip.empty?
            resolved = resolve_property_value(value)
            properties[key] = resolved if resolved != value
          end
        end
      end

      def resolve_property_value(value)
        s = value.to_s.strip
        return resolve_single_reference(s) unless collection_form?(s)
        # SSOT: top-level-aware split via StructuredValues.
        elements = Opencdd::StructuredValues.unwrap_and_split(s)
        resolved = elements.map { |e| resolve_single_reference(e) }.compact
        Opencdd::StructuredValues.rejoin(resolved)
      end

      def collection_form?(s)
        (s.start_with?("(") && s.end_with?(")")) ||
          (s.start_with?("{") && s.end_with?("}"))
      end

      def resolve_single_reference(token)
        target = @database.resolve_reference(token)
        target&.irdi&.to_s || token
      end
    end
  end
end
