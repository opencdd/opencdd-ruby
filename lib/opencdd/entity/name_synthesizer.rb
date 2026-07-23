# frozen_string_literal: true

module Opencdd
  class Entity
    # Reverse name-to-ID resolution for Parcel sheets that omit the
    # #PROPERTY_ID directive row. Some cdd.iec.ch export formats
    # (notably RELATION exports) include only #PROPERTY_NAME.en,
    # leaving the importer unable to map column positions to property
    # IDs. NameSynthesizer bridges that gap using the IEC 62656-1
    # defined column names.
    #
    # Extracted from SheetSchema so SheetSchema focuses on header
    # parsing + Column construction. Name synthesis is a separate
    # concern with its own test surface.
    module NameSynthesizer
      # IEC 62656-1 defined column names mapped to canonical
      # property IDs. These names appear in the #PROPERTY_NAME
      # directive row when #PROPERTY_ID is absent.
      NAME_TO_PROPERTY_ID = {
        "Code"                   => "MDC_P001_5",
        "Version"                => "MDC_P002_1",
        "Revision"               => "MDC_P002_2",
        "VersionInitiationDate"  => "MDC_P003_1",
        "VersionReleaseDate"     => "MDC_P003_2",
        "RevisionReleaseDate"    => "MDC_P003_3",
        "PreferredName"          => "MDC_P004",
        "SynonymousName"         => "MDC_P007",
        "ShortName"              => "MDC_P005",
        "Definition"             => "MDC_P006",
        "DefinitionSource"       => "MDC_P006_1",
        "Note"                   => "MDC_P008",
        "Remark"                 => "MDC_P009",
        "Drawing"                => "MDC_P008_1",
        "GUID"                   => "MDC_P066",
        "TimeStamp"              => "MDC_P067",
        "ClassType"              => "MDC_P011",
        "Superclass"             => "MDC_P010",
        "IsCaseOf"               => "MDC_P013",
        "ApplicableProperties"   => "MDC_P014",
        "ImportedProperties"     => "MDC_P090",
        "SubClassSelection"      => "MDC_P016",
        "DataType"               => "MDC_P022",
        "ValueFormat"            => "MDC_P024",
        "DefinitionClass"        => "MDC_P021",
        "Unit"                   => "MDC_P041",
        "Condition"              => "MDC_P028",
        "ListType"               => "MDC_P046",
        "CodeList"               => "MDC_P044",
        "TermList"               => "MDC_P043",
        "EnumerationCode"        => "MDC_P044",
        "RelationType"           => "MDC_P200",
        "RelationDomain"         => "MDC_P201",
        "FunctionDomain"         => "MDC_P202",
        "FunctionCodomain"       => "MDC_P203",
        "Formula"                => "MDC_P204",
        "FormulaLanguage"        => "MDC_P205",
        "FormulaExternalSolver"  => "MDC_P206",
        "TriggerEvent"           => "MDC_P207",
        "DomainElementType"      => "MDC_P208",
        "CodomainElementType"    => "MDC_P209",
        "Role"                   => "MDC_P210",
        "Segment"                => "MDC_P211",
        "SuperRelation"          => "MDC_P212",
      }.freeze

      # Given a PROPERTY_NAME directive row (Array of name strings),
      # returns a parallel Array of property IDs (or nil where the
      # name is unrecognized). Language suffixes (.EN, .FR) are
      # stripped for lookup and re-appended to the synthesized ID.
      #
      #   synthesize(["Code", "PreferredName.EN", "Unknown"])
      #   => ["MDC_P001_5", "MDC_P004.en", nil]
      def self.synthesize(name_values)
        Array.new(name_values.size) do |idx|
          val = name_values[idx]
          next nil if val.nil? || val.to_s.strip.empty?
          raw = val.to_s.strip
          if raw =~ /\A(.+)\.([A-Za-z]{2})\z/
            base = $1
            lang = $2
            pid = NAME_TO_PROPERTY_ID[base]
            pid ? "#{pid}.#{lang.downcase}" : nil
          else
            NAME_TO_PROPERTY_ID[raw]
          end
        end
      end
    end
  end
end
