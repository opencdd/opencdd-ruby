# frozen_string_literal: true

module Cdd
  module PropertyIds
    Entry = Struct.new(:id, :aliases, :applies_to, :multilingual, :value_kind, keyword_init: true)

    REGISTRY = {
      # ── Identity & version (applies_to: :all) ─────────────────────────
      "MDC_P001"    => Entry.new(id: "MDC_P001",    aliases: %w[code_generic],            applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_1"  => Entry.new(id: "MDC_P001_1",  aliases: %w[code_dictionary],         applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_2"  => Entry.new(id: "MDC_P001_2",  aliases: %w[code_supplier],           applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_5"  => Entry.new(id: "MDC_P001_5",  aliases: %w[code],                    applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_6"  => Entry.new(id: "MDC_P001_6",  aliases: %w[code_property],           applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_7"  => Entry.new(id: "MDC_P001_7",  aliases: %w[code_datatype],           applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_8"  => Entry.new(id: "MDC_P001_8",  aliases: %w[code_document],           applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_10" => Entry.new(id: "MDC_P001_10", aliases: %w[code_unit],               applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_11" => Entry.new(id: "MDC_P001_11", aliases: %w[code_value_term],         applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_12" => Entry.new(id: "MDC_P001_12", aliases: %w[code_value_list],         applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P001_13" => Entry.new(id: "MDC_P001_13", aliases: %w[code_relation],           applies_to: :all, multilingual: false, value_kind: :string),
      "EXT_P001"    => Entry.new(id: "EXT_P001",    aliases: %w[code_view_control],       applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P002_1"  => Entry.new(id: "MDC_P002_1",  aliases: %w[version],                 applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P002_2"  => Entry.new(id: "MDC_P002_2",  aliases: %w[revision],               applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P003_1"  => Entry.new(id: "MDC_P003_1",  aliases: %w[original_definition_date], applies_to: :all, multilingual: false, value_kind: :date),
      "MDC_P003_2"  => Entry.new(id: "MDC_P003_2",  aliases: %w[current_version_date],    applies_to: :all, multilingual: false, value_kind: :date),
      "MDC_P003_3"  => Entry.new(id: "MDC_P003_3",  aliases: %w[current_revision_date],   applies_to: :all, multilingual: false, value_kind: :date),

      # ── Names & definitions (applies_to: :all, mostly multilingual) ──
      "MDC_P004"   => Entry.new(id: "MDC_P004",   aliases: %w[preferred_name],            applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P004_1" => Entry.new(id: "MDC_P004_1", aliases: %w[preferred_name_localized],  applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P004_2" => Entry.new(id: "MDC_P004_2", aliases: %w[synonymous_names],          applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P004_3" => Entry.new(id: "MDC_P004_3", aliases: %w[short_name_localized],      applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P004_4" => Entry.new(id: "MDC_P004_4", aliases: %w[name_icon],                 applies_to: :all, multilingual: false, value_kind: :identifier_ref),
      "MDC_P005"   => Entry.new(id: "MDC_P005",   aliases: %w[short_name],                applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P005_1" => Entry.new(id: "MDC_P005_1", aliases: %w[short_name_variant],        applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P006"   => Entry.new(id: "MDC_P006",   aliases: %w[definition],                applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P006_1" => Entry.new(id: "MDC_P006_1", aliases: %w[source_document_of_definition], applies_to: :all, multilingual: false, value_kind: :identifier_ref),
      "MDC_P007"   => Entry.new(id: "MDC_P007",   aliases: %w[synonym],                   applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P007_1" => Entry.new(id: "MDC_P007_1", aliases: %w[note_localized],            applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P007_2" => Entry.new(id: "MDC_P007_2", aliases: %w[remark_localized],          applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P008"   => Entry.new(id: "MDC_P008",   aliases: %w[note],                      applies_to: :all, multilingual: true,  value_kind: :string),
      "MDC_P008_1" => Entry.new(id: "MDC_P008_1", aliases: %w[simplified_drawing],        applies_to: :all, multilingual: false, value_kind: :identifier_ref),
      "MDC_P008_2" => Entry.new(id: "MDC_P008_2", aliases: %w[graphics],                  applies_to: :all, multilingual: false, value_kind: :identifier_ref),
      "MDC_P009"   => Entry.new(id: "MDC_P009",   aliases: %w[remark],                    applies_to: :all, multilingual: true,  value_kind: :string),

      # ── Class-level (applies_to: :class) ──────────────────────────────
      "MDC_P010"   => Entry.new(id: "MDC_P010",   aliases: %w[superclass],                          applies_to: :class, multilingual: false, value_kind: :identifier_ref),
      "MDC_P010_1" => Entry.new(id: "MDC_P010_1", aliases: %w[superclass_localized known_superclasses], applies_to: :class, multilingual: false, value_kind: :identifier_ref),
      "MDC_P011"   => Entry.new(id: "MDC_P011",   aliases: %w[class_type],                          applies_to: :class, multilingual: false, value_kind: :string),
      "MDC_P012"   => Entry.new(id: "MDC_P012",   aliases: %w[supplier_class_ref],                  applies_to: :class, multilingual: false, value_kind: :identifier_ref),
      "MDC_P013"   => Entry.new(id: "MDC_P013",   aliases: %w[is_case_of],                          applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P014"   => Entry.new(id: "MDC_P014",   aliases: %w[applicable_properties],               applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P014_1" => Entry.new(id: "MDC_P014_1", aliases: %w[known_applicable_properties],         applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P014_2" => Entry.new(id: "MDC_P014_2", aliases: %w[visible_properties],                  applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P015"   => Entry.new(id: "MDC_P015",   aliases: %w[applicable_types],                    applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P015_1" => Entry.new(id: "MDC_P015_1", aliases: %w[known_applicable_types],              applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P015_2" => Entry.new(id: "MDC_P015_2", aliases: %w[visible_types],                       applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P016"   => Entry.new(id: "MDC_P016",   aliases: %w[sub_class_selection],                 applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P033"   => Entry.new(id: "MDC_P033",   aliases: %w[type_classification],                 applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P040"   => Entry.new(id: "MDC_P040",   aliases: %w[det_classification],                  applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P090"   => Entry.new(id: "MDC_P090",   aliases: %w[imported_properties],                 applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P091"   => Entry.new(id: "MDC_P091",   aliases: %w[imported_types],                      applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P093"   => Entry.new(id: "MDC_P093",   aliases: %w[imported_documents],                  applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P094"   => Entry.new(id: "MDC_P094",   aliases: %w[applicable_documents],                applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P094_1" => Entry.new(id: "MDC_P094_1", aliases: %w[known_applicable_documents],          applies_to: :class, multilingual: false, value_kind: :set_of_refs),
      "MDC_P094_2" => Entry.new(id: "MDC_P094_2", aliases: %w[visible_documents],                   applies_to: :class, multilingual: false, value_kind: :set_of_refs),

      # ── Property-level (applies_to: :property unless noted) ──────────
      "MDC_P017"   => Entry.new(id: "MDC_P017",   aliases: %w[class_value_assignment],    applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P018"   => Entry.new(id: "MDC_P018",   aliases: %w[coded_name],               applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P018_1" => Entry.new(id: "MDC_P018_1", aliases: %w[value_term_data_type],     applies_to: :all,       multilingual: false, value_kind: :class_ref),
      "MDC_P020"   => Entry.new(id: "MDC_P020",   aliases: %w[property_data_element_type property_det], applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P021"   => Entry.new(id: "MDC_P021",   aliases: %w[definition_class],         applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P022"   => Entry.new(id: "MDC_P022",   aliases: %w[data_type],                applies_to: :property, multilingual: false, value_kind: :class_ref),
      "MDC_P023"   => Entry.new(id: "MDC_P023",   aliases: %w[unit_structure unit_symbol], applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P023_1" => Entry.new(id: "MDC_P023_1", aliases: %w[unit_in_text],             applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P023_2" => Entry.new(id: "MDC_P023_2", aliases: %w[unit_in_sgml],             applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P024"   => Entry.new(id: "MDC_P024",   aliases: %w[value_format],             applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P025_1" => Entry.new(id: "MDC_P025_1", aliases: %w[symbol preferred_symbol_text symbol_in_text], applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P025_2" => Entry.new(id: "MDC_P025_2", aliases: %w[preferred_symbol_sgml],    applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P025_3" => Entry.new(id: "MDC_P025_3", aliases: %w[synonymous_symbol],        applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P026"   => Entry.new(id: "MDC_P026",   aliases: [],                           applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P026_1" => Entry.new(id: "MDC_P026_1", aliases: [],                           applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P027_1" => Entry.new(id: "MDC_P027_1", aliases: %w[formula_text property_formula], applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P027_2" => Entry.new(id: "MDC_P027_2", aliases: %w[formula_sgml property_formula_localized], applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P028"   => Entry.new(id: "MDC_P028",   aliases: %w[condition],                applies_to: :property, multilingual: false, value_kind: :condition),
      "MDC_P030"   => Entry.new(id: "MDC_P030",   aliases: [],                           applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P031"   => Entry.new(id: "MDC_P031",   aliases: [],                           applies_to: :property, multilingual: false, value_kind: :set_of_refs),
      "MDC_P032"   => Entry.new(id: "MDC_P032",   aliases: [],                           applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P041"   => Entry.new(id: "MDC_P041",   aliases: %w[unit unit_irdi codefor_unit], applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P042"   => Entry.new(id: "MDC_P042",   aliases: %w[alternative_units codefor_alt_unit], applies_to: :property, multilingual: false, value_kind: :set_of_refs),
      "MDC_P043"   => Entry.new(id: "MDC_P043",   aliases: %w[enumerated_terms term_irdis], applies_to: :value_list, multilingual: false, value_kind: :set_of_refs),
      "MDC_P044"   => Entry.new(id: "MDC_P044",   aliases: %w[enumerated_values code_list], applies_to: :value_list, multilingual: false, value_kind: :set_of_refs),
      "MDC_P045"   => Entry.new(id: "MDC_P045",   aliases: %w[selection_count],          applies_to: :value_list, multilingual: false, value_kind: :string),
      "MDC_P046"   => Entry.new(id: "MDC_P046",   aliases: %w[list_type],                applies_to: :value_list, multilingual: false, value_kind: :string),
      "MDC_P068"   => Entry.new(id: "MDC_P068",   aliases: %w[constraint property_constraint], applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P096"   => Entry.new(id: "MDC_P096",   aliases: %w[property_classification],  applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P097"   => Entry.new(id: "MDC_P097",   aliases: %w[requirement],              applies_to: :property, multilingual: false, value_kind: :string),
      "MDC_P101"   => Entry.new(id: "MDC_P101",   aliases: %w[alternate_id],             applies_to: :all,       multilingual: false, value_kind: :string),
      "MDC_P102"   => Entry.new(id: "MDC_P102",   aliases: %w[alternate_class_id],       applies_to: :all,       multilingual: false, value_kind: :string),
      "MDC_P110"   => Entry.new(id: "MDC_P110",   aliases: %w[super_property],           applies_to: :property, multilingual: false, value_kind: :identifier_ref),
      "MDC_P111"   => Entry.new(id: "MDC_P111",   aliases: %w[alternative_units_list],   applies_to: :property, multilingual: false, value_kind: :set_of_refs),
      "MDC_P112"   => Entry.new(id: "MDC_P112",   aliases: %w[description],              applies_to: :all,       multilingual: true,  value_kind: :string),
      "MDC_P113"   => Entry.new(id: "MDC_P113",   aliases: %w[example],                  applies_to: :all,       multilingual: false, value_kind: :string),
      "MDC_P114"   => Entry.new(id: "MDC_P114",   aliases: %w[quantity],                 applies_to: :property, multilingual: false, value_kind: :identifier_ref),

      # ── Relation-level (applies_to: :relation) ────────────────────────
      "MDC_P200"   => Entry.new(id: "MDC_P200",   aliases: %w[relation_type],            applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P201"   => Entry.new(id: "MDC_P201",   aliases: %w[domain domain_of_relation], applies_to: :relation, multilingual: false, value_kind: :set_of_refs),
      "MDC_P202"   => Entry.new(id: "MDC_P202",   aliases: %w[domain_of_function],       applies_to: :relation, multilingual: false, value_kind: :set_of_refs),
      "MDC_P203"   => Entry.new(id: "MDC_P203",   aliases: %w[codomain codomain_of_function], applies_to: :relation, multilingual: false, value_kind: :identifier_ref),
      "MDC_P204"   => Entry.new(id: "MDC_P204",   aliases: %w[formula relation_formula],  applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P205"   => Entry.new(id: "MDC_P205",   aliases: %w[formula_language],         applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P206"   => Entry.new(id: "MDC_P206",   aliases: %w[external_solver],          applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P207"   => Entry.new(id: "MDC_P207",   aliases: %w[trigger_event],            applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P208"   => Entry.new(id: "MDC_P208",   aliases: %w[domain_element_type],      applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P209"   => Entry.new(id: "MDC_P209",   aliases: %w[codomain_element_type],    applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P210"   => Entry.new(id: "MDC_P210",   aliases: %w[role],                     applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P211"   => Entry.new(id: "MDC_P211",   aliases: %w[segment],                  applies_to: :relation, multilingual: false, value_kind: :string),
      "MDC_P212"   => Entry.new(id: "MDC_P212",   aliases: %w[super_relation_irdi super_relation], applies_to: :relation, multilingual: false, value_kind: :identifier_ref),
      "MDC_P230"   => Entry.new(id: "MDC_P230",   aliases: %w[applicable_relations],     applies_to: :relation, multilingual: false, value_kind: :set_of_refs),
      "MDC_P231"   => Entry.new(id: "MDC_P231",   aliases: %w[applicable_terms],         applies_to: :relation, multilingual: false, value_kind: :set_of_refs),

      # ── CIM extension ─────────────────────────────────────────────────
      "CIM_P001"   => Entry.new(id: "CIM_P001",   aliases: %w[cim_uml_id],               applies_to: :all, multilingual: false, value_kind: :string),
      "CIM_P002"   => Entry.new(id: "CIM_P002",   aliases: %w[cim_package],              applies_to: :all, multilingual: false, value_kind: :string),
      "CIM_P003"   => Entry.new(id: "CIM_P003",   aliases: %w[cim_property_type],        applies_to: :all, multilingual: false, value_kind: :string),
      "CIM_P004"   => Entry.new(id: "CIM_P004",   aliases: %w[cim_basic_datatype],       applies_to: :all, multilingual: false, value_kind: :string),
      "CIM_P005"   => Entry.new(id: "CIM_P005",   aliases: %w[cim_multiplicity],         applies_to: :all, multilingual: false, value_kind: :string),

      # ── Global (applies_to: :all) ─────────────────────────────────────
      "MDC_P066"   => Entry.new(id: "MDC_P066",   aliases: %w[data_object_identifier],   applies_to: :all, multilingual: false, value_kind: :string),
      "MDC_P067"   => Entry.new(id: "MDC_P067",   aliases: %w[time_stamp],               applies_to: :all, multilingual: false, value_kind: :date_time),

      # ── View-control extension ────────────────────────────────────────
      "EXT_P002"   => Entry.new(id: "EXT_P002",   aliases: %w[controlled_classes],       applies_to: :view_control, multilingual: false, value_kind: :set_of_refs),
      "EXT_P003"   => Entry.new(id: "EXT_P003",   aliases: %w[shown_properties],         applies_to: :view_control, multilingual: false, value_kind: :set_of_refs),
    }.freeze

    PARCEL_VARIANT_TO_CANONICAL = {
      "MDC_P004_1" => "MDC_P004",
      "MDC_P004_2" => "MDC_P007",
      "MDC_P004_3" => "MDC_P005",
      "MDC_P005"   => "MDC_P006",
      "MDC_P007_1" => "MDC_P008",
      "MDC_P007_2" => "MDC_P009",
    }.freeze

    REGISTRY.each_key do |id|
      const_set(id, id.freeze) unless const_defined?(id, false)
    end

    def self.entry(id)
      REGISTRY[id.to_s]
    end

    def self.canonical_id(name)
      key = name.to_s
      return key if REGISTRY.key?(key)
      alias_map[key]
    end

    def self.multilingual?(id)
      e = entry(id)
      e ? e.multilingual : false
    end

    def self.applies_to(id)
      e = entry(id)
      e ? e.applies_to : nil
    end

    def self.value_kind(id)
      e = entry(id)
      e ? e.value_kind : nil
    end

    def self.all_ids
      @all_ids ||= REGISTRY.keys.freeze
    end

    def self.alias_map
      @alias_map ||= REGISTRY.each_with_object({}) do |(_id, e), h|
        e.aliases.each { |a| h[a] = e.id }
      end.freeze
    end

    def self.normalize(raw_id)
      return nil if raw_id.nil?
      s = raw_id.to_s.strip
      return nil if s.empty?
      match = s.match(/\.(?<lang>[A-Za-z0-9-]+)\z/)
      base = match ? match.pre_match : s
      lang = match && match[:lang]
      canonical = canonical_id(base) || base
      lang ? "#{canonical}.#{lang}" : canonical
    end

    def self.canonical_parcel_id(raw_id)
      return nil if raw_id.nil?
      s = raw_id.to_s.strip
      return nil if s.empty?
      match = s.match(/\.(?<lang>[A-Za-z0-9-]+)\z/)
      base = match ? match.pre_match : s
      lang = match && match[:lang]
      canonical = PARCEL_VARIANT_TO_CANONICAL[base] || base
      lang ? "#{canonical}.#{lang}" : canonical
    end
  end
end
