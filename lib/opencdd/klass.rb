# frozen_string_literal: true

module Opencdd
  class Klass < Opencdd::Entity
    PARENT_PROPERTY_IDS = [Opencdd::PropertyIds::MDC_P010_1, Opencdd::PropertyIds::MDC_P010].freeze

    # Read-only accessors for state that the Database mutates via
    # the explicit mutator methods below. Exposing only readers
    # (instead of attr_accessor) keeps the entity's invariants
    # under the class's control: parent linkage, child registration,
    # and declared-property tracking each have a single mutator
    # that can guard against duplicates, cycles, and stale state.
    attr_reader :parent_irdi, :children, :declared_property_irdis, :database

    def initialize(irdi: nil, properties:, schema: nil, meta_class_irdi: nil)
      super
      @children = []
      @declared_property_irdis = []
    end

    # ── Mutators (called by Opencdd::Database and Opencdd::Cddal::Builder
    #     during finalize/link phases). Single entry points keep
    #     invariant checks (dedup, validity) in one place. ──────

    def attach_parent_irdi(irdi)
      @parent_irdi = irdi
      self
    end

    def add_child(klass)
      return self if @children.include?(klass)
      @children << klass
      self
    end

    def declare_property(irdi)
      return self if @declared_property_irdis.include?(irdi)
      @declared_property_irdis << irdi
      self
    end

    def attach_database(database)
      @database = database
      self
    end

    # ── Pure field reads ─────────────────────────────────────────
    field :is_case_of_irdis,           "MDC_P013", as: "is_case_of"
    field :applicable_property_irdis,  "MDC_P014", as: "applicable_properties"
    field :imported_property_irdis,    "MDC_P090", as: "imported_properties"
    field :sub_class_selection_irdis,  "MDC_P016", as: "sub_class_selection"
    field :applicable_documents,       "MDC_P094"
    field :imported_documents,         "MDC_P093"

    # ── Computed fields with block-form readers ──────────────────
    field(:class_type, synthetic: true) do
      @class_type ||= Opencdd::ClassType.parse(properties[Opencdd::PropertyIds::MDC_P011])
    end
    field(:superclass_irdi, synthetic: true, as: "superclass") do
      raw = properties[Opencdd::PropertyIds::MDC_P010_1] || properties[Opencdd::PropertyIds::MDC_P010]
      next nil if raw.nil? || raw.to_s.strip.empty?
      Opencdd::IRDI.parse(raw)
    end
    field(:superclass_type_property, synthetic: true) do
      properties[Opencdd::PropertyIds::MDC_P010_1] || properties[Opencdd::PropertyIds::MDC_P010]
    end

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

    # ── Powertype semantics (CDD four-layer ontology) ───────────
    #
    # A CATEGORICAL_CLASS at M1 occupies the powertype position: its
    # subclasses ARE themselves classes, but they are also treated
    # as *instances* of the categorical class for the purpose of
    # CLASS_REFERENCE data types and sub_class_selection. This is
    # the distinguishing capability of CDD vs UML/RDF/OWL.
    #
    # Example (OceanRunner):
    #   EngineType (CATEGORICAL_CLASS)
    #     ├── SingleDieselEngine  (ITEM_CLASS)
    #     ├── TwinDieselEngine    (ITEM_CLASS)
    #     └── ElectricHybridEngine (ITEM_CLASS)
    #
    # EngineType#powertype? returns true.
    # EngineType#categorical_instances returns [SingleDiesel, TwinDiesel,
    # ElectricHybrid] — the valid values for any CLASS_REFERENCE(EngineType)
    # property.

    def powertype?
      categorical?
    end

    # Returns the powertype instances of this categorical class —
    # direct children that are themselves classes (ITEM_CLASS or
    # VALUE_CLASS terminal types). Returns empty for non-powertype
    # classes or when +database+ is unavailable.
    def categorical_instances(database = @database)
      return [] unless powertype? && database
      children.select { |c| c.item? || c.value_class? || c.powertype? }
    end

    # Sub-powertypes: categorical classes that specialize this one.
    # E.g. PrimaryColor (CATEGORICAL) under Color (CATEGORICAL) is a
    # sub-powertype. Useful for hierarchical option trees.
    def sub_powertypes(database = @database)
      return [] unless powertype? && database
      children.select(&:powertype?)
    end

    # Walks the ancestor chain and returns the categorical classes
    # this class is an instance of (in the powertype sense). For
    # SingleDiesel: [EngineType]. For a configured product subclass
    # under EngineType + InteriorPackage: [EngineType, InteriorPackage].
    def powertype_owners(database = @database)
      return [] unless database
      ancestors.filter_map do |a|
        next if a == self
        a if a.powertype?
      end
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

    def detect_parent_property_id
      return Opencdd::PropertyIds::MDC_P010 unless @schema

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
