# frozen_string_literal: true

require "set"
require "pathname"

module Cdd
  module Cddal
    class Builder
      attr_reader :database, :alias_table, :symbol_table, :meta_class_overrides

      def initialize(database = nil)
        @database = database || Cdd::Database.new
        @alias_table = Cdd::AliasTable.new(defaults: true)
        @symbol_table = {}
        @instance_decls = []
        @meta_class_overrides = {}
        @imported_urls = Set.new
      end

      def build(document_or_declarations)
        document = wrap_document(document_or_declarations)
        apply_alias_declarations(document)
        apply_meta_class_declarations(document)
        apply_import_declarations(document)
        register_instance_symbols(document)
        instantiate_entities(document)
        resolve_property_references(document)
        link_class_hierarchy
        link_property_classes
        link_value_lists
        rebuild_symbol_table
        @database.finalize!
        @database
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
          meta = Cdd::MetaClass::MetaClasses.for(decl.irdi)
          extension = Cdd::MetaClass.new(
            irdi: decl.irdi,
            name: meta&.name || decl.irdi,
            entity_class: meta&.entity_class,
            allowed_property_ids: decl.property_ids.map { |id| resolve_property_id(id) },
          )
          @meta_class_overrides[decl.irdi] = extension
          Cdd::MetaClass::MetaClasses.register(extension)
        end
      end

      def apply_import_declarations(document)
        document.import_declarations.each do |decl|
          next if @imported_urls.include?(decl.url)
          @imported_urls << decl.url
          source = read_import(decl.url)
          next unless source
          sub_doc = Cdd::Cddal::Parser.parse(source)
          Builder.new(@database).build(sub_doc)
        end
      end

      def read_import(url)
        return nil if url.to_s.empty?
        return nil if url =~ /\Ahttps?:\/\//
        path = expand_import_path(url)
        return nil unless path && File.exist?(path)
        File.read(path)
      end

      def expand_import_path(url)
        Pathname.new(url).expand_path
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
          @database.add_entity(entity)
          @database.register_symbol(decl.name, entity) if decl.name
        end
      end

      def build_entity(decl)
        meta_class = resolve_meta_class(decl.meta_class_ref)
        return nil unless meta_class && meta_class.entity_class

        properties = build_properties(decl)
        irdi = extract_irdi(properties)
        meta_irdi = Cdd::IRDI.parse(meta_class.irdi)

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
        return Cdd::MetaClass::MetaClasses.for(ref) if ref.to_s.match?(/\AMDC_C\d+\z/) || ref.to_s.match?(/\AEXT_C\d+\z/)

        canonical = resolve_property_id(ref)
        Cdd::MetaClass::MetaClasses.for(canonical) if canonical
      end

      def build_properties(decl)
        props = {}
        decl.assignments.each do |assignment|
          property_id = resolve_property_id(assignment.identifier)
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

      def resolve_property_id(name)
        return name.to_s if name.to_s.match?(/\AMDC_P\d+/) || name.to_s.match?(/\AEXT_P\d+/)
        resolved = @alias_table.resolve(name.to_s)
        resolved || name.to_s
      end

      def serialize_value(value, property_id)
        case value
        when AST::Literal
          value.raw
        when AST::IdentifierRef
          value.to_s
        when AST::Set
          elements = value.elements.map { |e| serialize_set_element(e) }
          "{#{elements.join(',')}}"
        when AST::Tuple
          elements = value.elements.map { |e| serialize_tuple_element(e) }
          "(#{elements.join(',')})"
        when AST::ClassReference
          argument = case value.argument
                     when AST::IdentifierRef then value.argument.name
                     else value.argument.to_s
                     end
          "#{value.type_name}(#{argument})"
        when AST::Condition
          rhs = value.right.to_cddal
          "#{value.left} #{value.operator} #{rhs}"
        else
          value.to_s
        end
      end

      def serialize_set_element(element)
        case element
        when AST::IdentifierRef then element.to_s
        when AST::Literal       then element.raw
        when AST::Tuple         then serialize_value(element, nil)
        when AST::Set           then serialize_value(element, nil)
        else element.to_s
        end
      end

      def serialize_tuple_element(element)
        case element
        when AST::IdentifierRef then element.to_s
        when AST::Literal       then element.raw
        else element.to_s
        end
      end

      def extract_irdi(properties)
        raw = properties[Cdd::PropertyIds::MDC_P001_5] || properties[Cdd::PropertyIds::MDC_P001_6] ||
              properties[Cdd::PropertyIds::MDC_P001_10] || properties[Cdd::PropertyIds::MDC_P001_11] ||
              properties[Cdd::PropertyIds::MDC_P001_12] || properties[Cdd::PropertyIds::MDC_P001_13]
        return nil unless raw
        Cdd::IRDI.parse(raw.to_s)
      end

      def link_class_hierarchy
        @database.classes.each do |klass|
          parent_id = klass.parent_property_id || Cdd::PropertyIds::MDC_P010
          parent_raw = klass.properties[parent_id]
          next if parent_raw.nil? || parent_raw.to_s.strip.empty?
          target = @database.resolve_reference(parent_raw)
          next unless target
          klass.parent_irdi = target.irdi
          target.children << klass unless target.children.include?(klass)
        end
      end

      def link_property_classes
        @database.properties.each do |prop|
          dc_raw = prop.properties[Cdd::PropertyIds::MDC_P021]
          next unless dc_raw
          target = @database.resolve_reference(dc_raw)
          next unless target&.is_a?(Cdd::Klass)
          unless target.declared_property_irdis.include?(prop.irdi)
            target.declared_property_irdis << prop.irdi
          end
        end
      end

      def link_value_lists
      end

      def rebuild_symbol_table
      end

      def resolve_property_references(document)
        reference_kinds = %i[identifier_ref set_of_refs class_ref].freeze
        reference_property_ids = Set.new(
          Cdd::PropertyIds::REGISTRY.select { |_, e| reference_kinds.include?(e.value_kind) }.keys
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
        return resolve_single_reference(s) unless wrapped_collection?(s)
        inner = s[1..-2]
        elements = inner.split(",").map(&:strip).reject(&:empty?)
        resolved = elements.map { |e| resolve_single_reference(e) }.compact
        "{#{resolved.join(',')}}"
      end

      def wrapped_collection?(s)
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
