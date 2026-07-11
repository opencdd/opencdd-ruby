# frozen_string_literal: true

module Cdd
  class Entity
    # Registry of declared fields on Entity subclasses. Open/closed:
    # adding a field is a single `field` declaration in the entity
    # class body — no edits to switch statements elsewhere.
    module FieldRegistry
      Entry = Struct.new(
        :entity_class, :name, :property_id, :value_kind,
        :multilingual, :synthetic, :reader, :block, :json_key,
        keyword_init: true,
      ) do
        def synthetic?    = !!synthetic
        def multilingual? = !!multilingual

        # True when this field's value is computed by a block rather
        # than read directly from +properties+. FieldReader dispatches
        # block-defined fields via +instance_exec+, which preserves
        # access to private helpers — no +send+ bypass required.
        def block?
          !block.nil?
        end

        # The key to use when serializing this field to JSON. Defaults
        # to the field's ruby name. Override via the `as:` DSL option
        # when the wire-format name should differ from the method
        # name (e.g. is_case_of_irdis → is_case_of).
        def wire_name
          (json_key || name).to_s
        end
      end

      @by_class = Hash.new { |h, k| h[k] = {} }

      class << self
        # Register a field on +entity_class+. The DSL in Entity.field
        # is the only intended caller. Re-registering the same name on
        # the same class overwrites the prior declaration (useful for
        # subclasses overriding the value_kind).
        #
        # Synthetic fields prefer the +block:+ form: the block is
        # evaluated via +instance_exec+ on the entity when the field
        # is read, so it has access to private helpers without
        # requiring +send+ dispatch. The legacy +reader:+ form
        # (a Symbol naming a public method on the entity) is accepted
        # for back-compat but should not be used for new fields.
        def register(entity_class:, name:, property_id:, value_kind:,
                     multilingual: false, synthetic: false, reader: nil,
                     block: nil, json_key: nil)
          entry = Entry.new(
            entity_class: entity_class,
            name: name.to_sym,
            property_id: property_id,
            value_kind: value_kind,
            multilingual: multilingual,
            synthetic: synthetic,
            reader: reader,
            block: block,
            json_key: json_key,
          )
          @by_class[entity_class][entry.name] = entry
          entry
        end

        # Lookup a single field by name on +entity_class+. Walks up
        # the ancestor chain so subclasses see inherited fields.
        def field_for(entity_class, name)
          each_entry(entity_class) { |e| return e if e.name == name.to_sym }
          nil
        end

        # Every field visible on +entity_class+, including inherited
        # fields. Order: base-class declarations first, then subclass
        # overrides (last wins on duplicate names).
        def fields_for(entity_class)
          seen = {}
          each_entry(entity_class) { |e| seen[e.name] = e }
          seen.values
        end

        private

        # Walk ancestors from most-generic (Entity) to most-specific,
        # yielding each declared entry along the way. Subclass
        # declarations come last so they overwrite base-class entries
        # with the same name (visible to #fields_for via the `seen`
        # hash in callers).
        def each_entry(entity_class)
          entity_class.ancestors.reverse_each do |klass|
            next unless klass.is_a?(Class)
            entries = @by_class[klass]
            entries.each_value { |e| yield e } if entries
          end
        end
      end
    end
  end
end
