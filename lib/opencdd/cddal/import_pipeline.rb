# frozen_string_literal: true

module Opencdd
  module Cddal
    # Handles CDDAL module imports: resolution, cycle detection,
    # recursive sub-document building, and symbol scoping.
    #
    # Extracted from Builder so the import pipeline has its own
    # testable interface. Builder creates an ImportPipeline and
    # delegates +apply_import_declarations+ to it.
    #
    # The pipeline holds shared mutable state (loaded_modules,
    # loading_stack) that persists across recursive sub-builds.
    # This state is passed by reference from the parent Builder
    # so all levels of the import tree share the same cycle
    # tracking.
    class ImportPipeline
      def initialize(database:, resolver:, source_file:, loaded_modules:, loading_stack:, qualified_table:)
        @database = database
        @resolver = resolver
        @source_file = source_file
        @loaded_modules = loaded_modules
        @loading_stack = loading_stack
        @qualified_table = qualified_table
      end

      def process(import_declarations)
        import_declarations.each { |decl| process_import(decl) }
      end

      private

      def process_import(decl)
        canonical, source = @resolver.resolve(decl.specifier, importing_file: @source_file)
        return if canonical.nil?
        return if @loaded_modules.key?(canonical)
        check_cycle!(canonical, decl.specifier)

        @loading_stack.push(canonical)
        sub_doc = Opencdd::Cddal::Parser.parse(source)
        Builder.new(@database, resolver: @resolver, source_file: canonical,
                                loaded_modules: @loaded_modules,
                                loading_stack: @loading_stack,
                                qualified_table: @qualified_table)
          .build(sub_doc)
        @loading_stack.pop
        @loaded_modules[canonical] = true

        apply_import_scope(decl)
      end

      def check_cycle!(canonical, specifier)
        return unless @loading_stack.include?(canonical)
        cycle = @loading_stack.dup
        cycle << canonical
        raise Opencdd::Cddal::ImportError,
              "circular CDDAL import detected: #{cycle.join(' → ')} " \
              "(originally imported as #{specifier.inspect})"
      end

      def apply_import_scope(decl)
        case decl.kind
        when :bare
          # Bare imports leave names in the shared symbol table.
        when :qualified
          register_qualified_symbols(decl.qualifier)
        when :selective
          register_selective_symbols(decl.imported_names)
        end
      end

      def register_qualified_symbols(qualifier)
        @database.entities.each do |entity|
          name = entity_alias_name(entity)
          next unless name
          qualified = "#{qualifier}.#{name}"
          @qualified_table[qualified] = entity
          @database.register_symbol(qualified, entity)
        end
      end

      def register_selective_symbols(imported_names)
        imported_names.each do |imported|
          entity = @database.resolve_reference(imported.name)
          next unless entity
          @database.register_symbol(imported.local_name, entity)
        end
      end

      def entity_alias_name(entity)
        code = entity.code
        return code if code && !code.empty?
        entity.preferred_name.to_s
      end
    end
  end
end
