# frozen_string_literal: true

module Cdd
  autoload :VERSION, "cdd/version"

  autoload :IRDI,        "cdd/irdi"

  autoload :PropertyIds, "cdd/property_ids"
  autoload :AliasTable,  "cdd/alias_table"

  autoload :MetaClass,   "cdd/meta_class"
  autoload :MetaClasses, "cdd/meta_class"

  autoload :ClassType,              "cdd/class_type"
  autoload :DataType,               "cdd/data_type"
  autoload :ValueFormat,            "cdd/value_format"
  autoload :StructuredValues,       "cdd/structured_values"

  autoload :PropertyDataTypeElement, "cdd/property_data_element_type"
  autoload :Condition,               "cdd/condition"
  autoload :RelationType,            "cdd/relation_type"

  autoload :Entity,      "cdd/entity"
  autoload :Klass,       "cdd/klass"
  autoload :Property,    "cdd/property"
  autoload :Unit,        "cdd/unit"
  autoload :ValueList,   "cdd/value_list"
  autoload :ValueTerm,   "cdd/value_term"
  autoload :Relation,    "cdd/relation"
  autoload :ViewControl, "cdd/view_control"

  autoload :Database,            "cdd/database"
  autoload :EffectiveProperties, "cdd/effective_properties"
  autoload :CompositionTree,     "cdd/composition_tree"
  autoload :RelationTree,        "cdd/relation_tree"
  autoload :Reader,              "cdd/reader"
  autoload :ClassTree,           "cdd/class_tree"
  autoload :Visitor,             "cdd/visitor"

  autoload :Parcel, "cdd/parcel"

  autoload :ParseHelpers, "cdd/parse_helpers"

  autoload :Validator, "cdd/validator"
  autoload :InstanceRule, "cdd/instance_rule"
  autoload :CompositionTree, "cdd/composition_tree"
  autoload :GUID, "cdd/guid"

  autoload :Exporters, "cdd/exporters"

  autoload :Cddal, "cdd/cddal"

  autoload :Codegen, "cdd/codegen"
end
