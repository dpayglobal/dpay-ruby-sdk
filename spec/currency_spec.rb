# frozen_string_literal: true

RSpec.describe DPay::Currency do
  it "exposes supported currency constants" do
    expect(described_class::PLN).to eq("PLN")
    expect(described_class::EUR).to eq("EUR")
    expect(described_class::CZK).to eq("CZK")
  end

  it "accepts any ISO-shaped uppercase code" do
    expect(described_class.valid?("GBP")).to be(true)
    expect { described_class.assert_valid("GBP") }.not_to raise_error
  end

  it "rejects malformed codes" do
    expect(described_class.valid?("pln")).to be(false)
    expect { described_class.assert_valid("pln") }.to raise_error(DPay::InvalidArgumentError)
    expect { described_class.assert_valid("PLNN") }.to raise_error(DPay::InvalidArgumentError)
  end
end
