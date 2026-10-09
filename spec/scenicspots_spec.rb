# frozen_string_literal: true

require "spec_helper"

# The ScenicSpots fixture demonstrates the full power-type chain:
# classes, plain instances (countries), extended instances
# (ScenicSpotType members carrying own applicable properties),
# configured subclasses (BuddhistTemple), and registered individuals
# (real scenic spots) with native multilingual names.

RSpec.describe "ScenicSpots dictionary" do
  before { require_fixture SCENICSPOTS }
  let(:db) { Opencdd::Cddal.parse_file(SCENICSPOTS) }

  it "loads every entity" do
    expect(db.entities.size).to eq(164)
  end

  describe "powertypes" do
    it "marks all three classification dimensions as powertypes" do
      expect(db.find_by_code("SPA100").powertype?).to be(true) # ScenicSpotType
      expect(db.find_by_code("SPA120").powertype?).to be(true) # ReligiousTradition
      expect(db.find_by_code("SPA130").powertype?).to be(true) # OfficialGrade
    end

    it "enumerates the spot kinds as extended instances" do
      spot_type = db.find_by_code("SPA100")
      codes = db.instances_of(spot_type).map(&:code).sort
      expect(codes).to eq(%w[SPA101 SPA102 SPA103 SPA104 SPA105 SPA106 SPA107 SPA108 SPA109 SPA110
                             SPA111 SPA112])
    end

    it "enumerates countries as plain instances" do
      country = db.find_by_code("SPA010")
      expect(db.instances_of(country).map(&:code).sort).to eq(%w[SPA011 SPA012 SPA013 SPA014 SPA015
                                                             SPA016 SPA017 SPA018 SPA019 SPA020
                                                             SPA021 SPA022 SPA023 SPA024 SPA025
                                                             SPA026 SPA027 SPA028 SPA029 SPA030
                                                             SPA031 SPA032 SPA033 SPA034 SPA035
                                                             SPA036 SPA037 SPA038 SPA039 SPA040])
    end
  end

  describe "extended instances as classes" do
    it "gives HotSpring its own applicable properties" do
      hot_spring = db.find_by_code("SPA105")
      expect(hot_spring.properties_on_class.map(&:code).sort)
        .to eq(%w[SPB106 SPB107 SPB208 SPB209]) # water_temperature, mineral_type, flow_rate, source_depth
    end

    it "gives Temple its own applicable properties" do
      temple = db.find_by_code("SPA102")
      expect(temple.properties_on_class.map(&:code).sort).to eq(%w[SPB102 SPB103 SPB203])
    end

    it "classifies Longshan Temple through the folk-tradition configured subclass" do
      folk_temple = db.find_by_code("SPA152")
      expect(folk_temple.parent&.code).to eq("SPA102") # Temple
      expect(folk_temple.sub_class_selection.map(&:code)).to eq(%w[SPA123]) # FolkShrine
      expect(db.find_by_code("SPI001").parent&.code).to eq("SPA152") # Longshan Temple
    end

    it "subclasses the Temple extended instance via a configured subclass" do
      buddhist_temple = db.find_by_code("SPA150")
      expect(buddhist_temple.parent&.code).to eq("SPA102") # Temple
      expect(buddhist_temple.sub_class_selection.map(&:code)).to eq(%w[SPA121]) # Buddhist
    end
  end

  describe "conditional properties" do
    it "applies the tradition property only to temples" do
      tradition = db.find_by_code("SPB003")
      expect(tradition).to be_conditional
      expect(tradition.condition.to_s).to eq("spot_type == Temple")
    end

    it "applies inscription year only to world-heritage spots" do
      inscription = db.find_by_code("SPB131")
      expect(inscription).to be_conditional
      expect(inscription.condition.to_s).to eq("official_grade == WorldHeritage")
    end
  end

  describe "effective properties across the power-type chain" do
    it "merges core, temple-specific, and tradition properties for Kinkaku-ji" do
      kinkakuji = db.find_by_code("SPI101")
      codes = kinkakuji.effective_properties.map(&:code).sort
      expect(codes).to include("SPB001", "SPB002", "SPB003", "SPB004",
                               "SPB007", "SPB008", "SPB009",
                               "SPB102", "SPB103")
      expect(codes).not_to include("SPB106") # water_temperature is HotSpring-only
    end

    it "keeps hot-spring properties off a national park" do
      taroko = db.find_by_code("SPI002")
      codes = taroko.effective_properties.map(&:code).map(&:to_s)
      expect(codes).to include("SPB101") # trail_count
      expect(codes).not_to include("SPB106", "SPB102")
    end
  end

  describe "native multilingual names" do
    it "carries each country's native name alongside English" do
      expect(db.find_by_code("SPI001").preferred_name("zh-TW")).to eq("艋舺龍山寺")
      expect(db.find_by_code("SPI001").preferred_name(:en)).to eq("Longshan Temple")
      expect(db.find_by_code("SPI101").preferred_name(:ja)).to eq("金閣寺")
      expect(db.find_by_code("SPI101").preferred_name(:en)).to eq("Kinkaku-ji")
      expect(db.find_by_code("SPI201").preferred_name(:ko)).to eq("경복궁")
      expect(db.find_by_code("SPI301").preferred_name(:it)).to eq("Colosseo")
    end
  end

  describe "global registry" do
    it "registers the Eiffel Tower through the Landmark type with core height" do
      eiffel = db.find_by_code("SPI601")
      expect(eiffel.parent&.code).to eq("SPA110") # Landmark
      codes = eiffel.effective_properties.map(&:code)
      expect(codes).to include("SPB004", "SPB305") # core height + architectural_style
      expect(eiffel.preferred_name(:fr)).to eq("Tour Eiffel")
    end

    it "classifies Fushimi Inari under the Shinto tradition" do
      inari = db.find_by_code("SPI105")
      expect(db.find_by_code("SPA124").preferred_name(:ja)).to eq("神道")
      expect(inari.preferred_name(:ja)).to eq("伏見稲荷大社")
    end

    it "is the curated learning dictionary — the bulk registry lives in data-poi" do
      indiv = db.entities.map(&:code).grep(/\ASPI/)
      expect(indiv.size).to eq(26)
      expect(db.find_by_code("SPA019").preferred_name("zh-CN")).to eq("中國")
    end
  end
end
