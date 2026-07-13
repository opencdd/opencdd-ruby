# frozen_string_literal: true

module Opencdd
  autoload :VERSION, "opencdd/version"

  autoload :IRDI,        "opencdd/irdi"

  autoload :PropertyIds, "opencdd/property_ids"
  autoload :AliasTable,  "opencdd/alias_table"

  autoload :MetaClass,   "opencdd/meta_class"
  autoload :MetaClasses, "opencdd/meta_class"

  autoload :ClassType,              "opencdd/class_type"
  autoload :DataType,               "opencdd/data_type"
  autoload :ValueFormat,            "opencdd/value_format"
  autoload :StructuredValues,       "opencdd/structured_values"

  autoload :PropertyDataTypeElement, "opencdd/property_data_element_type"
  autoload :Condition,               "opencdd/condition"
  autoload :RelationType,            "opencdd/relation_type"

  autoload :Entity,      "opencdd/entity"
  autoload :Klass,       "opencdd/klass"
  autoload :Property,    "opencdd/property"
  autoload :Unit,        "opencdd/unit"
  autoload :ValueList,   "opencdd/value_list"
  autoload :ValueTerm,   "opencdd/value_term"
  autoload :Relation,    "opencdd/relation"
  autoload :ViewControl, "opencdd/view_control"

  autoload :Database,            "opencdd/database"
  autoload :EffectiveProperties, "opencdd/effective_properties"
  autoload :CompositionTree,     "opencdd/composition_tree"
  autoload :RelationTree,        "opencdd/relation_tree"
  autoload :Reader,              "opencdd/reader"
  autoload :ClassTree,           "opencdd/class_tree"
  autoload :Visitor,             "opencdd/visitor"

  autoload :Parcel, "opencdd/parcel"

  autoload :ParseHelpers, "opencdd/parse_helpers"

  autoload :Validator, "opencdd/validator"
  autoload :InstanceRule, "opencdd/instance_rule"
  autoload :GUID, "opencdd/guid"

  autoload :Exporters, "opencdd/exporters"

  autoload :Cddal, "opencdd/cddal"

  autoload :Codegen, "opencdd/codegen"

  autoload :Languages, "opencdd/languages"

  autoload :Model, "opencdd/model"
end
