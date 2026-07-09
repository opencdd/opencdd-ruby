# frozen_string_literal: true

module Cdd
  class Klass < Cdd::Entity
    PARENT_PROPERTY_IDS = [Cdd::PropertyIds::MDC_P010_1, Cdd::PropertyIds::MDC_P010].freeze

    attr_accessor :parent_irdi, :children, :declared_property_irdis
    attr_reader   :database

    def initialize(irdi: nil, properties:, schema: nil, meta_class_irdi: nil)
      super
      @children = []
      @declared_property_irdis = []
    end

    # ── Pure field reads ─────────────────────────────────────────
    field :is_case_of_irdis,           "MDC_P013", as: "is_case_of"
    field :applicable_property_irdis,  "MDC_P014", as: "applicable_properties"
    field :imported_property_irdis,    "MDC_P090", as: "imported_properties"
    field :sub_class_selection_irdis,  "MDC_P016", as: "sub_class_selection"
    field :applicable_documents,       "MDC_P094"
    field :imported_documents,         "MDC_P093"

    # ── Computed fields with custom readers ──────────────────────
    field :class_type, synthetic: true, reader: :read_class_type
    field :superclass_irdi, synthetic: true, reader: :read_superclass_irdi, as: "superclass"
    field :superclass_type_property,
          synthetic: true, reader: :read_superclass_type_property

    alias_method :parent_property_value, :superclass_irdi

    def parent_property_id
      return @parent_property_id if defined?(@parent_property_id)
      @parent_property_id = detect_parent_property_id
    end

    def parent
      return nil unless @parent_irdi && @database
      @database.find(@parent_irdi)
    end

    def ancestors
      out = []
      cur = self
      while cur
        out << cur
        ref = cur.parent_irdi || cur.superclass_irdi
        break unless ref
        break if out.any? { |a| a.irdi == ref }
        parent_obj = cur.database&.find(ref)
        break unless parent_obj
        cur = parent_obj
      end
      out
    end

    def descendants
      out = []
      queue = children.dup
      seen = { irdi => true }
      until queue.empty?
        c = queue.shift
        next if seen[c.irdi]
        seen[c.irdi] = true
        out << c
        queue.concat(c.children)
      end
      out
    end

    def subclasses
      children
    end

    def properties_on_class(database = @database)
      return [] unless database
      declared_property_irdis.map { |i| database.find(i) }.compact
    end

    def all_properties(database = @database)
      return effective_properties if database
      properties_on_class(database)
    end

    def effective_properties(database = @database)
      return [] unless database
      database.effective_properties.for(self)
    end

    def is_case_of(database = @database)
      return [] unless database
      is_case_of_irdis.map { |i| database.find(i) }.compact
    end

    def sub_class_selection(database = @database)
      return [] unless database
      sub_class_selection_irdis.map { |i| database.find(i) }.compact
    end

    def attach_database(database)
      @database = database
      self
    end

    def item?
      class_type&.item?
    end

    def categorical?
      class_type&.categorical?
    end

    def value_class?
      class_type&.value_class?
    end

    def message?
      class_type&.message?
    end

    private

    def read_class_type
      @class_type ||= Cdd::ClassType.parse(properties[Cdd::PropertyIds::MDC_P011])
    end

    def read_superclass_irdi
      raw = properties[Cdd::PropertyIds::MDC_P010_1] || properties[Cdd::PropertyIds::MDC_P010]
      return nil if raw.nil? || raw.to_s.strip.empty?
      Cdd::IRDI.parse(raw)
    end

    def read_superclass_type_property
      properties[Cdd::PropertyIds::MDC_P010_1] || properties[Cdd::PropertyIds::MDC_P010]
    end

    def detect_parent_property_id
      return Cdd::PropertyIds::MDC_P010 unless @schema

      PARENT_PROPERTY_IDS.each do |id|
        return id if @schema.find_by_property_id(id)
      end

      @schema.each do |col|
        next unless col.name.to_s =~ /superclass|subclass of|parent/i
        next if col.name.to_s =~ /sub alternate/i
        return col.property_id
      end

      col = @schema.find_by_name("Subclass of") || @schema.find_by_name("Superclass")
      col&.property_id
    end
  end
end
