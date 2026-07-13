# frozen_string_literal: true

module Opencdd
  module Cddal
    # Pure-function value serializer: converts AST value nodes into
    # the CDDAL/Parcel wire string form. Extracted from Builder
    # (TODO.impl/28) so the builder's property-assembly pipeline
    # is a consumer of this module rather than owning the logic.
    #
    # Stateless — safe to call from any context. The Builder mixes
    # this in for backward compatibility.
    module ValueSerializer
      module_function

      def serialize(value, property_id = nil)
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
        when AST::Tuple         then serialize(element, nil)
        when AST::Set           then serialize(element, nil)
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
    end
  end
end
