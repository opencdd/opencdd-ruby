require "spec_helper"
require "tmpdir"

RSpec.describe "Parcel writer string preservation (audit A3)" do
  # Reproduces the original bug: numeric-looking strings like "001" were
  # written as numeric cells and read back as 1, breaking semantically_equal?.
  # Fix: Parcel::Writer#add_data_sheets forces `types: :string` per row.
  let(:database) do
    klass = Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///62656_4#AAA001"),
      properties: {
        Opencdd::PropertyIds::MDC_P001_5 => "0112/2///62656_4#AAA001",
        Opencdd::PropertyIds::MDC_P004_1 => "Sample class",                  # preferred_name.en
        Opencdd::PropertyIds::MDC_P002_1 => "001",                           # version (the bug)
        Opencdd::PropertyIds::MDC_P002_2 => "01",                            # revision
      },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    Opencdd::Database.new.add_entity(klass)
  end

  it "preserves leading-zero strings through xlsx round-trip" do
    tmp = File.join(Dir.mktmpdir, "round-trip.xlsx")
    Opencdd::Parcel::Writer.new(database).write(tmp, parcel_id: "TEST")

    reloaded = Opencdd::Database.load_workbook(tmp)
    sample = reloaded.entities.first

    expect(sample.version).to eq("001")
    expect(sample.revision).to eq("01")
  end

  # Note: a full semantically_equal? round-trip test is blocked by a separate
  # multilingual key normalization gap (MDC_P004_1 vs MDC_P004.en). That's a
  # different audit item; not in scope here.
end
