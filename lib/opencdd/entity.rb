# frozen_string_literal: true

require "lutaml/model"

module Opencdd
  class Entity < Lutaml::Model::Serializable
    include Opencdd::ParseHelpers

    # Open/closed field declaration. Each `field :foo, "MDC_P###",
    # :kind` call registers a typed accessor on the entity class and
    # adds an entry to FieldRegistry. Adding a field is one line
    # here — no edits to switch statements in the exporter,
    # validators, or TS codegen (all read from FieldRegistry).
    autoload :FieldRegistry,   "opencdd/entity/field_registry"
    autoload :FieldReader,     "opencdd/entity/field_reader"
    autoload :VersionHistory,  "opencdd/entity/version_history"
    autoload :Yaml,            "opencdd/entity/yaml"
    autoload :NameSynthesizer, "opencdd/entity/name_synthesizer"

    class << self
      # Declare a typed field on this entity class. Defaults for
      # +value_kind+ and +multilingual+ are resolved from
      # +Opencdd::PropertyIds::REGISTRY+ when the +property_id+ is known
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
        Opencdd::Entity::FieldRegistry.register(
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
          Opencdd::Entity::FieldReader.read(self, name, lang: lang)
        end
      end

      private

      def resolve_from_registry(property_id)
        return [nil, false] unless property_id
        entry = Opencdd::PropertyIds::REGISTRY[property_id.to_s]
        return [nil, false] unless entry
        [entry.value_kind, entry.multilingual]
      end
    end

    META_CLASS_CODE = nil

    attr_reader :irdi, :properties, :schema, :meta_class_irdi, :source_location

    def self.from_row(row, schema:, meta_class_irdi:, code_property_id: nil)
      code_property_id ||= default_code_property_id(meta_class_irdi)
      raw_code = code_property_id && row[code_property_id]
      # Fall back to other known code property IDs when the entity-
      # specific one is absent (happens with name-only header sheets
      # where "Code" synthesizes to MDC_P001_5 regardless of type).
      if raw_code.nil? || raw_code.to_s.strip.empty?
        Opencdd::MetaClasses::CODE_PROPERTY_IDS.each_value do |alt_id|
          val = row[alt_id]
          next if val.nil? || val.to_s.strip.empty?
          raw_code = val
          break
        end
      end
      irdi = raw_code && Opencdd::IRDI.parse(raw_code)

      props = row.each_with_object({}) do |(k, v), h|
        next if k == "__row_index__"
        h[k] = v if v
      end

      new(irdi: irdi, properties: props, schema: schema, meta_class_irdi: meta_class_irdi)
    end

    def self.default_code_property_id(meta_class_irdi)
      Opencdd::MetaClasses.code_property_id_for(meta_class_irdi&.code)
    end

    def initialize(irdi: nil, properties: nil, schema: nil, meta_class_irdi: nil)
      super({})
      @irdi = irdi
      @properties = properties || {}
      @schema = schema
      @meta_class_irdi = meta_class_irdi
      @version_history = Opencdd::Entity::VersionHistory.new
    end

    def type
      Opencdd::Parcel::META_CLASS_TYPES[meta_class_irdi&.code]
    end

    def code
      @irdi&.code
    end

    alias_method :short, :code

    # Note: irdi and code are NOT declared as DSL fields — they're
    # emitted explicitly by Exporters::Json#entity_payload because
    # the model's `irdi` accessor must return the Opencdd::IRDI object
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
    #     Opencdd::Parcel::ShardedDirReader after entity creation. The
    #     DSL serializer converts VersionHistory → array of entry
    #     hashes for JSON emission.
    field(:version_history, synthetic: true) { @version_history }

    # ── Computed field with custom block ────────────────────────
    Dates = Struct.new(:original_definition, :current_version, :current_revision, keyword_init: true)

    field(:dates, synthetic: true) do
      Dates.new(
        original_definition: @properties[Opencdd::PropertyIds::MDC_P003_1],
        current_version:     @properties[Opencdd::PropertyIds::MDC_P003_2],
        current_revision:    @properties[Opencdd::PropertyIds::MDC_P003_3],
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
      other.is_a?(Opencdd::Entity) &&
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
      @irdi = Opencdd::IRDI === new_irdi ? new_irdi : Opencdd::IRDI.parse(new_irdi.to_s)
      self
    end

    def replace_code_value!(code_property_id, new_code)
      return self unless code_property_id
      @properties[code_property_id.to_s] = new_code.to_s
      self
    end

    # ── Field DSL access seam ───────────────────────────────────
    #
    # The canonical way to read or write a typed field on an entity.
    # Goes through FieldRegistry so multilingual, value-kind, and
    # synthetic-field semantics are consistent across all callers
    # (SheetEmitter, Json exporter, validator, GUID setter, etc.).
    # Callers that index +properties+ directly bypass these and
    # risk round-trip drift — see TODO.impl/26.

    # Read a declared field by name. Accepts an optional +lang:+ for
    # multilingual fields. Returns the typed value (parsed IRDI,
    # Array, etc.) per the field's declared value_kind.
    def read_field(name, lang: nil)
      Opencdd::Entity::FieldReader.read(self, name, lang: lang)
    end

    # Write a value to a property ID, routing through canonical-id
    # alias resolution so writes are consistent with reads. Use
    # this in preference to +entity.properties[id] = value+ from
    # non-infrastructure callers.
    def write_property!(id, value)
      canonical = Opencdd::PropertyIds.canonical_id(id.to_s) || id.to_s
      base = canonical.to_s.split(".").first
      @properties[base] = value.to_s
      self
    end

    # Attach per-version provenance captured in _entity.json. Called
    # by Opencdd::Parcel::ShardedDirReader after entity creation — the
    # constructor doesn't take it because FlatDirReader creates
    # entities from .xls rows without version context.
    def attach_version_history(version_history)
      @version_history = version_history
      self
    end

    # Attach source location (file:line) where this entity was
    # declared. Set by Opencdd::Cddal::Builder from import/instantiation
    # context. Nil for entities constructed from Parcel readers
    # (which don't have a single source file).
    def attach_source_location(loc)
      @source_location = loc
      self
    end

    # ── YAML persistence via Entity::Yaml ──────────────────────
    # Entity extends Lutaml::Model::Serializable but its own attribute
    # set is empty — the typed YAML model lives in Entity::Yaml
    # (the deepened adapter). This avoids name conflicts between the
    # field DSL getters (which read from @properties and return
    # coerced values like IRDI objects, source-language Strings,
    # parsed Arrays) and lutaml-model serialization attrs (which
    # must return flat types: String, Hash, Array).
    #
    # lutaml-model serialization calls +public_send(attr_name)+
    # during to_format, so any getter with the same name as a
    # YAML attr is invoked. Keeping the YAML model in Entity::Yaml
    # lets both worlds coexist: field DSL for domain access,
    # Entity::Yaml for serialization.

    def to_yaml(*args)
      Opencdd::Entity::Yaml.from_entity(self).to_yaml(*args)
    end

    def self.from_yaml(yaml_str)
      Opencdd::Entity::Yaml.from_yaml(yaml_str).to_entity
    end
  end
end
