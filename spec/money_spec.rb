# frozen_string_literal: true

RSpec.describe DPay::Money do
  it "builds from minor units" do
    money = described_class.pln(1050)

    expect(money.minor).to eq(1050)
    expect(money.currency).to eq("PLN")
    expect(money.to_decimal).to eq("10.50")
    expect(money.to_s).to eq("10.50 PLN")
  end

  it "renders the golden to_decimal matrix" do
    {
      1050 => "10.50", 1000 => "10.00", 5 => "0.05", 0 => "0.00",
      -2000 => "-20.00", -5 => "-0.05", 123_456_789 => "1234567.89"
    }.each do |minor, expected|
      expect(described_class.pln(minor).to_decimal).to eq(expected)
    end
  end

  it "parses decimal strings" do
    expect(described_class.from_decimal("10.50", DPay::Currency::PLN).minor).to eq(1050)
    expect(described_class.from_decimal("10.5", DPay::Currency::PLN).minor).to eq(1050)
    expect(described_class.from_decimal("10", DPay::Currency::PLN).minor).to eq(1000)
    expect(described_class.from_decimal("-30.00", DPay::Currency::PLN).minor).to eq(-3000)
  end

  it "rejects malformed decimals" do
    expect { described_class.from_decimal("10,50", DPay::Currency::PLN) }.to raise_error(DPay::InvalidArgumentError)
    expect { described_class.from_decimal("10.505", DPay::Currency::PLN) }.to raise_error(DPay::InvalidArgumentError)
  end

  it "matches the golden try_from_api_number matrix" do
    inputs = [30, 0, -7, 10.5, 8.285, 0.1, 29.999, "10", "10.5", "10.50", "0.05", "-0.05", "abc", true, nil]
    expected = [3000, 0, -700, 1050, 829, 10, 3000, 1000, 1050, 1050, 5, -5, nil, nil, nil]

    actual = inputs.map { |value| described_class.try_from_api_number(value, DPay::Currency::PLN)&.minor }

    expect(actual).to eq(expected)
  end

  it "raises from from_api_number on unusable values" do
    expect { described_class.from_api_number(true, DPay::Currency::PLN) }.to raise_error(DPay::InvalidArgumentError)
    expect(described_class.from_api_number(30, DPay::Currency::PLN).minor).to eq(3000)
    expect(described_class.from_api_number(29.99, DPay::Currency::PLN).minor).to eq(2999)
  end

  it "validates currency and compares by value" do
    expect { described_class.of(500, "zl") }.to raise_error(DPay::InvalidArgumentError)
    m = described_class.pln(100)
    expect(m).to eq(described_class.pln(100))
    expect(described_class.pln(100)).not_to eq(described_class.of(100, DPay::Currency::EUR))
    expect(described_class.pln(-1)).to be_negative
  end

  it "is frozen" do
    expect(described_class.pln(1)).to be_frozen
  end
end
