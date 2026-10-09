# frozen_string_literal: true

require "spec_helper"

# The Antiques fixture demonstrates the power-type model on an
# auction-style East Asian works-of-art domain: three stacked
# classification dimensions (category × period × culture) as
# powertypes, extended instances owning kind-specific properties,
# a root-level CONDITION_DET (`reign_mark` applies only to ceramics —
# the "Mark and Period" attribution pattern), configured subclasses
# (Ceramics × Ming, Ceramics × Goryeo), and registered individuals
# (well-known museum objects) with native multilingual names.
#
# Authored by OpenCDD from standard art-historical vocabulary; the
# public department listings of international auction houses were
# consulted as reference only (notes in the private data repo).

RSpec.describe "Antiques dictionary" do
  before { require_fixture ANTIQUES }
  let(:db) { Opencdd::Cddal.parse_file(ANTIQUES) }

  it "loads every entity" do
    expect(db.entities.size).to eq(148)
  end

  describe "powertypes" do
    it "marks all three classification dimensions as powertypes" do
      expect(db.find_by_code("ANA010").powertype?).to be(true) # Culture
      expect(db.find_by_code("ANA020").powertype?).to be(true) # Period
      expect(db.find_by_code("ANA100").powertype?).to be(true) # AntiqueCategory
    end

    it "enumerates the object categories as extended instances" do
      category = db.find_by_code("ANA100")
      codes = db.instances_of(category).map(&:code).sort
      expect(codes).to eq(%w[ANA101 ANA102 ANA103 ANA104 ANA105
                             ANA106 ANA107 ANA108 ANA109 ANA110])
    end

    it "enumerates twelve dynasties and eras" do
      period = db.find_by_code("ANA020")
      codes = db.instances_of(period).map(&:code).sort
      expect(codes).to eq(%w[ANA021 ANA022 ANA023 ANA024 ANA025 ANA026
                             ANA027 ANA028 ANA029 ANA030 ANA031 ANA032])
    end

    it "enumerates cultures as plain instances" do
      culture = db.find_by_code("ANA010")
      expect(db.instances_of(culture).map(&:code).sort).to eq(%w[ANA011 ANA012 ANA013])
    end
  end

  describe "extended instances as classes" do
    it "gives Ceramics its own applicable properties" do
      ceramics = db.find_by_code("ANA101")
      expect(ceramics.properties_on_class.map(&:code).sort)
        .to eq(%w[ANB101 ANB102]) # kiln, glaze
    end

    it "gives Bronze its own applicable properties" do
      bronze = db.find_by_code("ANA102")
      expect(bronze.properties_on_class.map(&:code).sort)
        .to eq(%w[ANB103 ANB104]) # vessel_form, inscription_characters
    end

    it "subclasses the Ceramics extended instance via period selection" do
      ming_blue_and_white = db.find_by_code("ANA150")
      expect(ming_blue_and_white.parent&.code).to eq("ANA101") # Ceramics
      expect(ming_blue_and_white.sub_class_selection.map(&:code)).to eq(%w[ANA027]) # Ming

      goryeo_celadon = db.find_by_code("ANA151")
      expect(goryeo_celadon.parent&.code).to eq("ANA101")
      expect(goryeo_celadon.sub_class_selection.map(&:code)).to eq(%w[ANA029]) # Goryeo
    end
  end

  describe "conditional properties" do
    it "applies the reign mark only to ceramics" do
      reign_mark = db.find_by_code("ANB007")
      expect(reign_mark).to be_conditional
      expect(reign_mark.condition.to_s).to eq("category == Ceramics")
    end
  end

  describe "effective properties across the power-type chain" do
    it "merges core and ceramics properties for the Xuande jar" do
      jar = db.find_by_code("ANI006")
      codes = jar.effective_properties.map(&:code).sort
      expect(codes).to include("ANB001", "ANB002", "ANB003", "ANB004",
                               "ANB005", "ANB006", "ANB007",
                               "ANB101", "ANB102")
      expect(codes).not_to include("ANB113") # print_format is Ukiyo-e-only
    end

    it "keeps print properties off a bronze vessel" do
      ding = db.find_by_code("ANI001")
      codes = ding.effective_properties.map(&:code).map(&:to_s)
      expect(codes).to include("ANB103", "ANB104") # vessel_form, inscription_characters
      expect(codes).not_to include("ANB101", "ANB113")
    end
  end

  describe "registered individuals" do
    it "classifies the Maebyeong vase through the configured subclass" do
      vase = db.find_by_code("ANI004")
      expect(vase.parent&.code).to eq("ANA151") # GoryeoCeladon
      expect(vase.effective_properties.map(&:code)).to include("ANB101", "ANB102")
    end

    it "registers the twelve curated museum objects" do
      codes = db.entities.map(&:code).grep(/\AANI/)
      %w[ANI001 ANI002 ANI003 ANI004 ANI005 ANI006
         ANI007 ANI008 ANI009 ANI010 ANI011 ANI012].each do |curated|
        expect(codes).to include(curated)
      end
    end

    it "carries the Met Museum Open Access bulk registry" do
      codes = db.entities.map(&:code).grep(/\AANI/)
      # 12 curated + 78 Met highlights, contiguous three-digit numbering
      expect(codes.size).to eq(90)
      expect(codes).to include("ANI013", "ANI050", "ANI090")
      met = db.find_by_code("ANI013")
      expect(met.preferred_name(:en)).to be_a(String)
      expect(met.definition).to include("The Metropolitan Museum of Art")
    end
  end

  describe "native multilingual names" do
    it "carries each object's native name alongside English" do
      expect(db.find_by_code("ANI001").preferred_name("zh-TW")).to eq("毛公鼎")
      expect(db.find_by_code("ANI001").preferred_name(:en)).to eq("Mao Gong Ding")
      expect(db.find_by_code("ANI002").preferred_name("zh-TW")).to eq("翠玉白菜")
      expect(db.find_by_code("ANI005").preferred_name("ja")).to eq("神奈川沖浪裏")
      expect(db.find_by_code("ANI004").preferred_name("ko")).to eq("고려청자 매병")
      expect(db.find_by_code("ANI007").preferred_name("ko")).to eq("달항아리")
    end

    it "carries native names on the classification dimensions too" do
      expect(db.find_by_code("ANA101").preferred_name("zh-TW")).to eq("陶瓷")
      expect(db.find_by_code("ANA027").preferred_name("zh-TW")).to eq("明")
      expect(db.find_by_code("ANA110").preferred_name("ja")).to eq("浮世絵")
      expect(db.find_by_code("ANA029").preferred_name("ko")).to eq("고려")
    end
  end
end
