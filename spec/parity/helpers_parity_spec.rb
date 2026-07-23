# frozen_string_literal: true

RSpec.describe "PHP helper parity" do
  let(:golden) { GoldenFixtures.php_sdk }

  it "matches the checksum helper vectors" do
    calculator = DPay::Internal::ChecksumCalculator.new("sekret-hash-123")

    expect(calculator.secret_second("test_service", [])).to eq(golden.dig("checksums", "secret_second_empty"))
    expect(calculator.secret_second("test_service", ["10.00", 42, 3.5, "https://a/b"]))
      .to eq(golden.dig("checksums", "secret_second_mixed"))
    expect(calculator.ordered_body(%w[test_service tx-1])).to eq(golden.dig("checksums", "ordered_simple"))
    expect(calculator.ordered_body(["test_service", 1_784_700_000, 4242, 10.0, true, false, ""]))
      .to eq(golden.dig("checksums", "ordered_mixed"))
  end

  it "matches the money to_decimal matrix" do
    golden["money_to_decimal"].each do |minor, expected|
      expect(DPay::Money.pln(Integer(minor)).to_decimal).to eq(expected)
    end
  end

  it "matches the money try_from_api matrix" do
    inputs = [30, 0, -7, 10.5, 8.285, 0.1, 29.999, "10", "10.5", "10.50", "0.05", "-0.05", "abc", true, nil]

    inputs.each_with_index do |value, index|
      money = DPay::Money.try_from_api_number(value, DPay::Currency::PLN)

      expect(money&.minor).to eq(golden["money_try_from_api"][index]), "money_try_from_api[#{index}]"
    end
  end

  it "matches the float cast matrix" do
    golden["float_cast"].each do |decimal, expected|
      expect(DPay::Internal::PHP.json_encode({ "amount" => decimal.to_f })).to eq(expected)
    end
  end

  it "matches the strval matrix" do
    inputs = [10.0, 10.5, 0.1, 1.0 / 3, 1e25, -0.0, 100.0, 828.5, true, false, 42, "abc"]

    inputs.each_with_index do |value, index|
      expect(DPay::Internal::PHP.strval(value)).to eq(golden["strval"][index]), "strval[#{index}]"
    end
  end

  it "matches every IPN vector" do
    golden["ipn"].each do |vector|
      event = DPay::IpnVerifier.construct_event(vector["body"], "sekret-hash-123")

      expect(event.signature).to eq(vector["signature"])
      expect(event.id).to eq(vector["id"])
      expect(event.amount).to eq(vector["amount"])
      expect(event.email).to eq(vector["email"])
      expect(event.type).to eq(vector["type"])
      expect(event.attempt).to eq(vector["attempt"])
      expect(event.version).to eq(vector["version"])
      expect(event.custom).to eq(vector["custom"])
      expect(event.capture_payment_id).to eq(vector["capture_payment_id"])
    end
  end

  it "matches the card payload" do
    encoded = DPay::Internal::PHP.json_encode(
      { "PN" => "4111111111111111", "SC" => "123", "DT" => "12/25", "ID" => "tx-1", "TX" => 1_784_700_000 },
      escape_slashes: true
    )

    expect(encoded).to eq(golden["card_payload"])
  end
end
