# frozen_string_literal: true

module Opencdd
  module Exporters
    class Mermaid < Opencdd::Visitor
      attr_reader :lines

      def initialize
        super
        @lines = ["classDiagram"]
      end

      def to_diagram(database)
        reset!
        @lines = ["classDiagram"]
        visit_classes(database)
        @lines.uniq.join("\n")
      end

      def visit_class(klass)
        emit_class_block(klass)
        parent_ref = klass.parent_irdi || klass.superclass_irdi
        if parent_ref
          parent = klass.database&.find(parent_ref)
          if parent
            safe = mermaid_id(parent)
            child = mermaid_id(klass)
            @lines << "  #{safe} <|-- #{child}"
          end
        end
        klass.is_case_of_irdis.each do |ref|
          target = klass.database&.find(ref)
          next unless target
          @lines << "  #{mermaid_id(target)} <.. #{mermaid_id(klass)} : is_case_of"
        end
        super
      end

      private

      def emit_class_block(klass)
        id = mermaid_id(klass)
        @lines << "  class #{id} {"
        @lines << "    <<#{klass.class_type || 'ITEM_CLASS'}>>"
        @lines << "    +code #{klass.code}"
        @lines << "  }"
        note = klass.preferred_name
        @lines << "  #{id} : #{quote_label(note)}" if note && !note.empty?
      end

      def mermaid_id(klass)
        code = klass.code&.to_s
        return "Class_#{klass.irdi.to_s.gsub(/[^A-Za-z0-9]/, "_")}" if code.nil? || code.empty?
        code.gsub(/[^A-Za-z0-9_]/, "_")
      end

      def quote_label(text)
        text.to_s.include?(":") ? "\"#{text}\"" : text.to_s
      end
    end
  end
end
