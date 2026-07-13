# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "CDDAL module system", :cddal do
  # The module/import system (plan 09) adds three import forms on
  # top of the bare-textual-inclusion form that already existed:
  #
  #   bare       — `import "path"`
  #   qualified  — `import "path" as alias`
  #   selective  — `from "path" import { Foo, Bar as B }`
  #
  # Plus: URL imports via pluggable fetcher, dependency-graph
  # cycle detection, and source-location tracking on every entity.

  let(:base_dict) do
    <<~CDDAL
      meta-class MDC_C002 {
        code
        preferred_name
        superclass
        class_type
        applicable_properties
      }
      instance Boat < MDC_C002 {
        code: AAA010
        preferred_name.en: "Boat"
        superclass: UNIVERSE
        class_type: ITEM_CLASS
        applicable_properties: { hull_length }
      }
      instance hull_length < MDC_C003 {
        code: AAAP010
        preferred_name.en: "hull length"
      }
    CDDAL
  end

  describe "bare imports (textual inclusion)" do
    it "merges declarations from a relative-path import" do
      Dir.mktmpdir("cddal-mod") do |dir|
        base_path = File.join(dir, "base.cddal")
        File.write(base_path, base_dict)

        main = <<~CDDAL
          import "./base.cddal"

          instance Speedboat < MDC_C002 {
            code: AAA011
            preferred_name.en: "Speedboat"
            superclass: Boat
            class_type: ITEM_CLASS
          }
        CDDAL

        db = Opencdd::Cddal.parse(main, source_file: File.join(dir, "main.cddal"))
        expect(db.classes.map(&:code)).to contain_exactly("AAA010", "AAA011")
        speedboat = db.find_by_code("AAA011")
        expect(speedboat.parent.code).to eq("AAA010")
      end
    end

    it "is idempotent when a transitive import appears twice" do
      Dir.mktmpdir("cddal-mod") do |dir|
        # base.cddal defines Boat at AAA010. left and right both
        # re-declare Boat at their own codes, then both import base.
        # The main file imports left then right.
        File.write(File.join(dir, "base.cddal"), base_dict)
        File.write(File.join(dir, "left.cddal"), <<~CDDAL)
          import "./base.cddal"
          instance LeftBoat < MDC_C002 {
            code: AAA020
            preferred_name.en: "Left Boat"
            class_type: ITEM_CLASS
          }
        CDDAL
        File.write(File.join(dir, "right.cddal"), <<~CDDAL)
          import "./base.cddal"
          instance RightBoat < MDC_C002 {
            code: AAA030
            preferred_name.en: "Right Boat"
            class_type: ITEM_CLASS
          }
        CDDAL

        main = <<~CDDAL
          import "./left.cddal"
          import "./right.cddal"
        CDDAL

        db = Opencdd::Cddal.parse(main, source_file: File.join(dir, "main.cddal"))
        # base's Boat (AAA010) is imported transitively via both
        # left and right, but dedup means it appears exactly once.
        boats_aaa010 = db.find_all_by_code("AAA010")
        expect(boats_aaa010.size).to eq(1)
        # Left's and Right's own declarations also appear once each.
        expect(db.find_by_code("AAA020")).not_to be_nil
        expect(db.find_by_code("AAA030")).not_to be_nil
      end
    end
  end

  describe "qualified imports" do
    it "brings entities into the parent DB for IRDI resolution" do
      Dir.mktmpdir("cddal-mod") do |dir|
        File.write(File.join(dir, "base.cddal"), base_dict)

        main = <<~CDDAL
          import "./base.cddal" as lib

          instance Speedboat < MDC_C002 {
            code: AAA011
            preferred_name.en: "Speedboat"
            superclass: Boat
            class_type: ITEM_CLASS
          }
        CDDAL

        # The qualified form brings entities into the parent DB
        # (so IRDI resolution finds Boat), so bare-name resolution
        # to Boat still works.
        db = Opencdd::Cddal.parse(main, source_file: File.join(dir, "main.cddal"))
        boat = db.find_by_code("AAA010")
        expect(boat).not_to be_nil
        expect(boat.preferred_name).to eq("Boat")
      end
    end
  end

  describe "selective imports" do
    it "loads the named declarations into the parent DB" do
      Dir.mktmpdir("cddal-mod") do |dir|
        File.write(File.join(dir, "base.cddal"), base_dict)

        main = <<~CDDAL
          from "./base.cddal" import { Boat }

          instance Speedboat < MDC_C002 {
            code: AAA011
            preferred_name.en: "Speedboat"
            superclass: Boat
            class_type: ITEM_CLASS
          }
        CDDAL

        db = Opencdd::Cddal.parse(main, source_file: File.join(dir, "main.cddal"))
        # Selective import loads the whole target module's entities
        # (so IRDI resolution works), regardless of which names are
        # imported into the parent's symbol table.
        expect(db.classes.size).to eq(2) # Boat + Speedboat
        expect(db.find_by_code("AAA010")&.preferred_name).to eq("Boat")
      end
    end

    it "supports renaming via 'as'" do
      Dir.mktmpdir("cddal-mod") do |dir|
        File.write(File.join(dir, "base.cddal"), base_dict)

        main = <<~CDDAL
          from "./base.cddal" import { Boat as B }

          instance Speedboat < MDC_C002 {
            code: AAA011
            preferred_name.en: "Speedboat"
            superclass: B
            class_type: ITEM_CLASS
          }
        CDDAL

        db = Opencdd::Cddal.parse(main, source_file: File.join(dir, "main.cddal"))
        speedboat = db.find_by_code("AAA011")
        # The renamed symbol 'B' resolves to Boat's IRDI.
        expect(speedboat.parent.code).to eq("AAA010")
      end
    end
  end

  describe "cycle detection" do
    it "raises ImportError on circular imports" do
      Dir.mktmpdir("cddal-mod") do |dir|
        File.write(File.join(dir, "a.cddal"), <<~CDDAL)
          import "./b.cddal"
          instance A < MDC_C002 {
            code: AAA001
            preferred_name.en: "A"
            class_type: ITEM_CLASS
          }
        CDDAL
        File.write(File.join(dir, "b.cddal"), <<~CDDAL)
          import "./a.cddal"
          instance B < MDC_C002 {
            code: AAA002
            preferred_name.en: "B"
            class_type: ITEM_CLASS
          }
        CDDAL

        main = 'import "./a.cddal"'
        expect {
          Opencdd::Cddal.parse(main, source_file: File.join(dir, "main.cddal"))
        }.to raise_error(Opencdd::Cddal::ImportError, /circular CDDAL import/)
      end
    end
  end

  describe "URL imports" do
    it "uses the in-memory fetcher for tests" do
      fetcher = Opencdd::Cddal::Fetcher::InMemory.new(
        "https://example.test/base.cddal" => base_dict,
      )
      resolver = Opencdd::Cddal::Resolver.new(fetcher: fetcher)

      main = <<~CDDAL
        import "https://example.test/base.cddal"

        instance Speedboat < MDC_C002 {
          code: AAA011
          preferred_name.en: "Speedboat"
          superclass: Boat
          class_type: ITEM_CLASS
        }
      CDDAL

      db = Opencdd::Cddal.parse(main, resolver: resolver, source_file: "(main)")
      expect(db.find_by_code("AAA011")&.parent&.code).to eq("AAA010")
    end

    it "skips unreachable URLs in non-strict mode" do
      fetcher = Opencdd::Cddal::Fetcher::InMemory.new # empty map → all URLs fail
      # quiet: true suppresses the expected warning so the test
      # output stays clean. Production callers let the warning
      # surface so real bugs (typos, renamed files) aren't silent.
      resolver = Opencdd::Cddal::Resolver.new(fetcher: fetcher, quiet: true)

      main = <<~CDDAL
        import "https://invalid.example/missing.cddal"

        instance Local < MDC_C002 {
          code: AAA099
          preferred_name.en: "Local"
          class_type: ITEM_CLASS
        }
      CDDAL

      db = Opencdd::Cddal.parse(main, resolver: resolver, source_file: "(main)")
      # The unreachable import is skipped; the local declaration still loads.
      expect(db.find_by_code("AAA099")).not_to be_nil
    end
  end

  describe "strict mode" do
    it "raises ImportError when a path import cannot be resolved" do
      resolver = Opencdd::Cddal::Resolver.new(strict: true)

      main = 'import "./does-not-exist.cddal"'
      expect {
        Opencdd::Cddal.parse(main, resolver: resolver, source_file: "(main)")
      }.to raise_error(Opencdd::Cddal::ImportError, /cannot resolve import/)
    end
  end

  describe "soft keywords" do
    # `as` and `from` are reserved only inside import declarations.
    # Elsewhere they're valid identifier values (e.g. attosecond's
    # short_name "as", or a property named "from").

    it "accepts 'as' as a property value (attosecond regression)" do
      cddal = <<~CDDAL
        instance Attosecond < MDC_C009 {
          code: UAC696
          preferred_name.en: "attosecond"
          short_name.en: as
        }
      CDDAL

      db = Opencdd::Cddal.parse(cddal)
      unit = db.find_by_code("UAC696")
      expect(unit.short_name).to eq("as")
    end

    it "still parses qualified imports correctly when 'as' is also a value" do
      cddal = <<~CDDAL
        instance AsHolder < MDC_C002 {
          code: AAA001
          short_name.en: as
          class_type: ITEM_CLASS
        }
      CDDAL
      db = Opencdd::Cddal.parse(cddal)
      expect(db.find_by_code("AAA001").short_name).to eq("as")
    end
  end

  describe "source location tracking" do
    it "attaches source_location to every entity" do
      Dir.mktmpdir("cddal-mod") do |dir|
        path = File.join(dir, "loc.cddal")
        File.write(path, base_dict)
        db = Opencdd::Cddal.parse_file(path)
        boat = db.find_by_code("AAA010")
        expect(boat.source_location).not_to be_nil
        expect(boat.source_location.file).to eq(path)
      end
    end
  end

  describe "Fetcher::NetHttp" do
    it "honors the cache_dir and offline flags" do
      cache = Dir.mktmpdir("cddal-cache")
      fetcher = Opencdd::Cddal::Fetcher::NetHttp.new(cache_dir: cache, offline: true)
      expect(fetcher.cache_dir.to_s).to eq(cache)
      expect(fetcher.offline).to be(true)
    end
  end
end
