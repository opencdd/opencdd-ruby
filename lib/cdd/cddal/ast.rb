# frozen_string_literal: true

module Cdd
  module Cddal
    module AST
      Document = Struct.new(:declarations, keyword_init: true) do
        def each_declaration
          return enum_for(:each_declaration) unless block_given?
          declarations.each { |d| yield d }
        end

        def meta_class_declarations
          declarations.select { |d| d.is_a?(MetaClassDecl) }
        end

        def instance_declarations
          declarations.select { |d| d.is_a?(InstanceDecl) }
        end

        def alias_declarations
          declarations.select { |d| d.is_a?(AliasDecl) }
        end

        def import_declarations
          declarations.select { |d| d.is_a?(ImportDecl) }
        end
      end

      MetaClassDecl = Struct.new(:irdi, :property_identifiers, :line, keyword_init: true) do
        def property_ids
          property_identifiers.map(&:to_s)
        end
      end

      InstanceDecl = Struct.new(:name, :meta_class_ref, :assignments, :line, keyword_init: true)

      AliasDecl = Struct.new(:alias_name, :property_id, :line, keyword_init: true)

      # One name in a selective import (`from "x" import { Foo, Bar as B }`).
      # +as+ is the optional local rename; when nil, the name is bound
      # under its original form.
      ImportedName = Struct.new(:name, :as, keyword_init: true) do
        def local_name
          as || name
        end
      end

      # CDDAL module import declaration. Three shapes, discriminated
      # by +kind+:
      #
      #   :bare       — textual inclusion of every named declaration
      #                 in the target. +specifier+ is the path/URL.
      #   :qualified  — target's names are accessible as
      #                 +<qualifier>.<name>+. +qualifier+ is the alias.
      #   :selective  — only the names in +imported_names+ are pulled
      #                 in, each subject to its optional rename.
      ImportDecl = Struct.new(
        :specifier, :kind, :qualifier, :imported_names, :line,
        keyword_init: true,
      ) do
        def self.bare(specifier, line:)
          new(specifier: specifier, kind: :bare, line: line)
        end

        def self.qualified(specifier, qualifier:, line:)
          new(specifier: specifier, kind: :qualified, qualifier: qualifier, line: line)
        end

        def self.selective(specifier, imported_names:, line:)
          new(specifier: specifier, kind: :selective, imported_names: imported_names, line: line)
        end

        # Backward-compat accessor for callers that expect +url+.
        def url
          specifier
        end
      end

      PropertyAssignment = Struct.new(:identifier, :language_tag, :value, :line, keyword_init: true) do
        def resolved_key
          language_tag ? "#{identifier}.#{language_tag}" : identifier
        end
      end

      Literal = Struct.new(:kind, :raw, keyword_init: true) do
        def value
          case kind
          when :number then raw.match?(/\A-?\d+\z/) ? raw.to_i : raw.to_f
          when :boolean then raw == "true"
          when :null then nil
          else raw
          end
        end

        def to_cddal
          case kind
          when :string then "\"#{escape(raw)}\""
          when :boolean, :null then raw
          else raw
          end
        end

        private

        def escape(s)
          s.to_s.gsub("\\", "\\\\").gsub('"', "\\\"")
        end
      end

      IdentifierRef = Struct.new(:name, :owner, keyword_init: true) do
        def qualified?
          !owner.nil?
        end

        def to_s
          qualified? ? "#{owner}.#{name}" : name
        end

        alias_method :to_cddal, :to_s
      end

      Set = Struct.new(:elements, keyword_init: true) do
        def identifiers
          elements
        end

        def to_cddal
          "{ #{elements.map(&:to_cddal).join(', ')} }"
        end
      end

      Tuple = Struct.new(:elements, keyword_init: true) do
        def to_cddal
          "(#{elements.map(&:to_cddal).join(', ')})"
        end
      end

      ClassReference = Struct.new(:type_name, :argument, keyword_init: true) do
        def to_cddal
          "#{type_name}(#{argument})"
        end
      end

      Condition = Struct.new(:left, :operator, :right, keyword_init: true) do
        def to_cddal
          "#{left} #{operator} #{right.to_cddal}"
        end
      end
    end
  end
end
