# frozen_string_literal: true

module Opencdd
  module Parcel
    META_CLASS_TYPES = Opencdd::MetaClasses::TYPE_BY_META_CLASS
    TYPE_TO_META_CLASS = META_CLASS_TYPES.invert.freeze

    autoload :Metadata,        "opencdd/parcel/metadata"
    autoload :SheetSchema,     "opencdd/parcel/sheet_schema"
    autoload :LanguageAliases, "opencdd/parcel/language_aliases"
    autoload :Sheet,           "opencdd/parcel/sheet"
    autoload :Workbook,        "opencdd/parcel/workbook"
    autoload :WorkbookReader,  "opencdd/parcel/workbook_reader"
    autoload :FlatDirReader,   "opencdd/parcel/flat_dir_reader"
    autoload :ShardedDirReader, "opencdd/parcel/sharded_dir_reader"
    autoload :VersionedReader,  "opencdd/parcel/versioned_reader"
    autoload :LayoutDetector,  "opencdd/parcel/layout_detector"
    autoload :EntityManifest,  "opencdd/parcel/entity_manifest"
    autoload :ReferencedIrdis,  "opencdd/parcel/referenced_irdis"
    autoload :Selector,        "opencdd/parcel/selector"
    autoload :SheetEmitter,    "opencdd/parcel/sheet_emitter"
    autoload :Writer,          "opencdd/parcel/writer"
    autoload :CsvWriter,       "opencdd/parcel/csv_writer"
    autoload :CsvReader,       "opencdd/parcel/csv_reader"
    autoload :ScrapeVerifier,  "opencdd/parcel/scrape_verifier"

    module_function

    # Aggregate multiple Parcel-shaped paths into a single Database.
    # The +paths+ array may contain .xlsx files, .xls files, flat .xls
    # directories, or sharded per-class subdirs. Each is read
    # polymorphically via +Opencdd::Reader.detect+ and merged into a
    # single target database.
    #
    # Returns the populated Opencdd::Database.
    def aggregate(*paths)
      paths.flatten
        .map { |p| Opencdd::Database.load(p) }
        .reduce(Opencdd::Database.new) { |acc, db| acc.merge(db) }
    end

    # Split +database+ into multiple sub-databases partitioned along
    # +by+:
    #
    #   :entity_type — one partition per entity type
    #     (the legacy .xls layout, one file per type).
    #   :root_class — one partition per root class
    #     (full tree per parcel, lifted cross-type deps).
    #   :each_class — one partition per class
    #     (the class + its declared properties / value_lists /
    #     relations / units).
    #   callable   — partition key is +callable.call(entity)+;
    #     the result is a +Hash{ key => Database }+.
    #
    # Returns +Hash{ key => Opencdd::Database }+.
    def split(database, by:, lift_dependencies: true)
      partitions = case by
                   when :entity_type then split_by_type(database)
                   when :root_class  then split_by_root_class(database, lift_dependencies: lift_dependencies)
                   when :each_class  then split_by_each_class(database, lift_dependencies: lift_dependencies)
                   when Proc         then split_by_callable(database, by)
                   else
                     raise ArgumentError, "split `by:` must be :entity_type, :root_class, :each_class, or a Proc"
                   end
      partitions
    end

    def split_by_type(database)
      database.entities.group_by(&:type).each_with_object({}) do |(type, entities), h|
        h[type] = build_partition(database, entities)
      end
    end

    def split_by_root_class(database, lift_dependencies: true)
      roots = database.root_classes
      roots.each_with_object({}) do |root, h|
        tree = collect_root_subtree(database, root)
        entities = lift_dependencies ? lift_for(database, tree) : tree
        h[root.code || root.irdi.to_s] = build_partition(database, entities)
      end
    end

    def split_by_each_class(database, lift_dependencies: true)
      database.classes.each_with_object({}) do |klass, h|
        entities = [klass]
        if lift_dependencies
          klass_props = database.properties_of(klass)
          entities.concat(klass_props)
          entities.concat(database.relations_for(domain: klass.irdi))
          klass_props.each do |prop|
            next unless prop.is_a?(Opencdd::Property)
            if prop.unit_irdi
              unit = database.find(prop.unit_irdi)
              entities << unit if unit.is_a?(Opencdd::Unit)
            end
            vl = database.value_list_of(prop)
            entities << vl if vl
          end
        end
        h[klass.code || klass.irdi.to_s] = build_partition(database, entities)
      end
    end

    def split_by_callable(database, callable)
      database.entities.group_by { |e| callable.call(e) }.each_with_object({}) do |(key, entities), h|
        h[key] = build_partition(database, entities)
      end
    end

    def collect_root_subtree(database, root)
      collected = [root]
      queue = [root]
      seen = { root.irdi => true }
      until queue.empty?
        current = queue.shift
        children = current.children
        children.each do |c|
          next if seen[c.irdi]
          seen[c.irdi] = true
          collected << c
          queue << c
        end
      end
      collected
    end

    # Lifts cross-type dependencies for the given set of classes:
    # declared properties, value_lists those properties reference,
    # units those properties use, and relations where the class is
    # in domain or codomain. This makes a per-tree partition
    # self-sufficient when written out.
    def lift_for(database, classes)
      entities = classes.dup
      classes.each do |klass|
        database.properties_of(klass).each { |p| entities << p unless entities.include?(p) }
        database.relations_for(domain: klass.irdi).each { |r| entities << r unless entities.include?(r) }
        database.relations_for(codomain: klass.irdi).each { |r| entities << r unless entities.include?(r) }
        database.properties_of(klass).each do |prop|
          next unless prop.is_a?(Opencdd::Property)
          if prop.unit_irdi
            unit = database.find(prop.unit_irdi)
            entities << unit if unit.is_a?(Opencdd::Unit) && !entities.include?(unit)
          end
          vl = database.value_list_of(prop)
          entities << vl if vl && !entities.include?(vl)
        end
      end
      entities.uniq
    end

    def build_partition(_database, entities)
      db = Opencdd::Database.new
      entities.each { |e| db.add_entity(deep_copy_entity(e)) }
      db.finalize!
      db
    end

    # Returns a detached copy of +entity+ — same +irdi+, +properties+,
    # +schema+, +meta_class_irdi+, but no +@database+ back-reference and
    # empty Klass-specific state (+@children+, +@declared_property_irdis+).
    #
    # The destination partition Database reattaches the entity and
    # rebuilds class-tree state via +add_entity+ and +finalize!+.
    #
    # We can't use Marshal here because Entity indirectly references its
    # source Database, which uses Hash.new { ... } (a default proc) for
    # its indexes — Marshal refuses to dump hashes with default procs.
    def deep_copy_entity(entity)
      entity.class.new(
        irdi: entity.irdi,
        properties: entity.properties.dup,
        schema: entity.schema,
        meta_class_irdi: entity.meta_class_irdi,
      )
    end
  end
end
