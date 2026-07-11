# frozen_string_literal: true

module Cdd
  class Entity
    include Cdd::ParseHelpers

    # Open/closed field declaration. Each `field :foo, "MDC_P###",
    # :kind` call registers a typed accessor on the entity class and
    # adds an entry to FieldRegistry. Adding a field is one line
    # here — no edits to switch statements in the exporter,
    # validators, or TS codegen (all read from FieldRegistry).
    autoload :FieldRegistry,   "cdd/entity/field_registry"
    autoload :FieldReader,     "cdd/entity/field_reader"
    autoload :VersionHistory,  "cdd/entity/version_history"

    class << self
      # Declare a typed field on this entity class. Defaults for
      # +value_kind+ and +multilingual+ are resolved from
      # +Cdd::PropertyIds::REGISTRY+ when the +property_id+ is known
      # there — the REGISTRY is the SSOT for wire-format metadata,
      # and re-declaring it here would violate DRY.
      #
      # Pass an explicit +value_kind+ to override (used when REGISTRY's
      # kind doesn't match how the field is consumed — e.g. MDC_P023
      # is :identifier_ref in REGISTRY but Unit#structure uses it as
      # a raw string).
      #
      # +synthetic: true+ for computed fields with no MDC_P### —
      # requires a block (preferred) that returns the value. The
      # block is evaluated via +instance_exec+ on the entity, so it
      # has access to private helpers without +send+ dispatch.
      def field(name, property_id = nil, value_kind = nil,
                multilingual: nil, synthetic: false, reader: nil,
                as: nil, &block)
        resolved_kind, resolved_ml = resolve_from_registry(property_id)
        Cdd::Entity::FieldRegistry.register(
          entity_class: self,
          name: name,
          property_id: property_id,
          value_kind: value_kind || resolved_kind || :string,
          multilingual: multilingual.nil? ? resolved_ml : multilingual,
          synthetic: synthetic,
          reader: reader,
          block: block,
          json_key: as,
        )
        define_method(name) do |lang = nil|
          Cdd::Entity::FieldReader.read(self, name, lang: lang)
        end
      end

      private

      def resolve_from_registry(property_id)
        return [nil, false] unless property_id
        entry = Cdd::PropertyIds::REGISTRY[property_id.to_s]
        return [nil, false] unless entry
        [entry.value_kind, entry.multilingual]
      end
    end

    META_CLASS_CODE = nil

    attr_reader :irdi, :properties, :schema, :meta_class_irdi, :source_location

    def self.from_row(row, schema:, meta_class_irdi:, code_property_id: nil)
      code_property_id ||= default_code_property_id(meta_class_irdi)
      raw_code = code_property_id && row[code_property_id]
      irdi = raw_code && Cdd::IRDI.parse(raw_code)

      props = row.each_with_object({}) do |(k, v), h|
        next if k == "__row_index__"
        h[k] = v if v
      end

      new(irdi: irdi, properties: props, schema: schema, meta_class_irdi: meta_class_irdi)
    end

    def self.default_code_property_id(meta_class_irdi)
      Cdd::MetaClasses.code_property_id_for(meta_class_irdi&.code)
    end

    def initialize(irdi:, properties:, schema: nil, meta_class_irdi: nil)
      @irdi = irdi
      @properties = properties
      @schema = schema
      @meta_class_irdi = meta_class_irdi
      @version_history = Cdd::Entity::VersionHistory.new
    end

    def type
      Cdd::Parcel::META_CLASS_TYPES[meta_class_irdi&.code]
    end

    def code
      @irdi&.code
    end

    alias_method :short, :code

    # ── Pure field reads (value_kind and multilingual auto-resolved
    #     from PropertyIds::REGISTRY). `as:` aliases preserve the
    #     existing JSON wire shape — ruby method names differ from
    #     historical JSON keys for backward compatibility. ─────────
    # Note: irdi and code are NOT declared as DSL fields — they're
    # emitted explicitly by Exporters::Json#entity_payload because
    # the model's `irdi` accessor must return the Cdd::IRDI object
    # (not a String); DSL emission would override it.
    field :version,           "MDC_P002_1"
    field :revision,          "MDC_P002_2"
    field :preferred_name,    "MDC_P004"   # multilingual via REGISTRY
    field :short_name,        "MDC_P005"   # multilingual via REGISTRY
    field :definition,        "MDC_P006"   # multilingual via REGISTRY
    # source_document wins the MDC_P006_1 dedup (declared before the
    # _of_definition alias); JSON key is "source_document".
    field :source_document,              "MDC_P006_1"
    field :source_document_of_definition, "MDC_P006_1"
    field :synonyms,           "MDC_P007", :synonym_pairs, multilingual: true, as: "synonyms"
    field :synonymous_names,   "MDC_P007", :synonym_pairs, multilingual: true
    field :note,              "MDC_P008"   # multilingual via REGISTRY
    field :simplified_drawing, "MDC_P008_1", :string
    field :remark,            "MDC_P009"   # multilingual via REGISTRY
    field :description,       "MDC_P112"   # multilingual via REGISTRY
    field :example,           "MDC_P113"
    field :guid,              "MDC_P066", as: "guid"
    field :data_object_identifier, "MDC_P066"
    field :time_stamp,        "MDC_P067"

    # ── C### workbook-specific codes. These are IEC CDD export column
    #     identifiers that don't have MDC_P### codes in PropertyIds::REGISTRY.
    #     They carry publisher, status, committee, and change-request data.
    #     Declared as synthetic (no MDC_P###) with block-form readers
    #     evaluated via instance_exec (no send-to-private bypass).
    field(:status_level,         synthetic: true) { @properties["C016"] }
    field(:publisher,            synthetic: true) { @properties["C011"] }
    field(:published_in,         synthetic: true) { @properties["C012"] }
    field(:responsible_committee, synthetic: true) { @properties["MDC_P012"] || @properties["C019.en"] }
    field(:change_request_id,    synthetic: true) { @properties["C002"] }

    # ── Full raw properties dump. Every key in @properties appears
    #     in the JSON output. This guarantees "full import" — every
    #     column from the .xls is preserved, including multilingual
    #     variants (MDC_P004.en/de/fr/zh), C### workbook-specific
    #     codes (status, publisher, etc.), and sub-IDs the DSL
    #     hasn't named yet. The browser can render typed fields
    #     nicely and fall back to raw_properties for completeness.
    field(:raw_properties, synthetic: true) { @properties }

    # ── Per-version provenance from _entity.json#versions. Set by
    #     Cdd::Parcel::ShardedDirReader after entity creation. The
    #     DSL serializer converts VersionHistory → array of entry
    #     hashes for JSON emission.
    field(:version_history, synthetic: true) { @version_history }

    # ── Computed field with custom block ────────────────────────
    Dates = Struct.new(:original_definition, :current_version, :current_revision, keyword_init: true)

    field(:dates, synthetic: true) do
      Dates.new(
        original_definition: @properties[Cdd::PropertyIds::MDC_P003_1],
        current_version:     @properties[Cdd::PropertyIds::MDC_P003_2],
        current_revision:    @properties[Cdd::PropertyIds::MDC_P003_3],
      )
    end

    def [](key)
      @properties[key.to_s]
    end

    def key?(key)
      @properties.key?(key.to_s)
    end

    def keys
      @properties.keys
    end

    def each_property
      return enum_for(:each_property) unless block_given?
      @properties.each { |k, v| yield k, v }
    end

    def eql?(other)
      other.is_a?(Cdd::Entity) &&
        irdi == other.irdi &&
        type == other.type
    end

    def hash
      [irdi, type].hash
    end

    alias_method :==, :eql?

    def inspect
      "#<#{self.class.name} #{irdi}>"
    end

    def replace_irdi!(new_irdi)
      @irdi = Cdd::IRDI === new_irdi ? new_irdi : Cdd::IRDI.parse(new_irdi.to_s)
      self
    end

    def replace_code_value!(code_property_id, new_code)
      return self unless code_property_id
      @properties[code_property_id.to_s] = new_code.to_s
      self
    end

    # Attach per-version provenance captured in _entity.json. Called
    # by Cdd::Parcel::ShardedDirReader after entity creation — the
    # constructor doesn't take it because FlatDirReader creates
    # entities from .xls rows without version context.
    def attach_version_history(version_history)
      @version_history = version_history
      self
    end

    # Attach source location (file:line) where this entity was
    # declared. Set by Cdd::Cddal::Builder from import/instantiation
    # context. Nil for entities constructed from Parcel readers
    # (which don't have a single source file).
    def attach_source_location(loc)
      @source_location = loc
      self
    end
  end
end
