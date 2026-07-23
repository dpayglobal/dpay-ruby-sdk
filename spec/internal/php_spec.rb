# frozen_string_literal: true

RSpec.describe DPay::Internal::PHP do
  describe ".strval" do
    it "maps PHP scalar casting semantics" do
      expect(described_class.strval(nil)).to eq("")
      expect(described_class.strval(true)).to eq("1")
      expect(described_class.strval(false)).to eq("")
      expect(described_class.strval(10)).to eq("10")
      expect(described_class.strval(100)).to eq("100")
      expect(described_class.strval("abc")).to eq("abc")
      expect(described_class.strval("")).to eq("")
    end

    it "formats floats like PHP" do
      expect(described_class.strval(10.0)).to eq("10")
      expect(described_class.strval(10.5)).to eq("10.5")
      expect(described_class.strval(0.1)).to eq("0.1")
      expect(described_class.strval(828.5)).to eq("828.5")
      expect(described_class.strval(1.0 / 3)).to eq("0.33333333333333")
      expect(described_class.strval(-0.0)).to eq("-0")
    end

    it "formats exponential floats like PHP" do
      expect(described_class.strval(1e25)).to eq("1.0E+25")
      expect(described_class.strval(1e-7)).to eq("1.0E-7")
    end
  end

  describe ".round" do
    it "rounds half away from zero" do
      expect(described_class.round(828.5)).to eq(829)
      expect(described_class.round(1050.0)).to eq(1050)
      expect(described_class.round(-828.5)).to eq(-829)
      expect(described_class.round(2999.9000000000005)).to eq(3000)
      expect(described_class.round(10.000000000000002)).to eq(10)
    end
  end

  describe ".json_encode" do
    it "encodes compactly and keeps insertion order" do
      expect(described_class.json_encode({ "b" => 1, "a" => 2 })).to eq('{"b":1,"a":2}')
      expect(described_class.json_encode({})).to eq("{}")
    end

    it "keeps unicode raw and does not escape slashes by default" do
      expect(described_class.json_encode({ "d" => "Zamówienie / ĄĘŚŻ" })).to eq('{"d":"Zamówienie / ĄĘŚŻ"}')
    end

    it "normalizes integral floats to integers like PHP" do
      expect(described_class.json_encode({ "amount" => 10.0 })).to eq('{"amount":10}')
      expect(described_class.json_encode({ "amount" => 29.99 })).to eq('{"amount":29.99}')
      expect(described_class.json_encode({ "amount" => -20.0 })).to eq('{"amount":-20}')
      expect(described_class.json_encode({ "amount" => 0.05 })).to eq('{"amount":0.05}')
      expect(described_class.json_encode({ "amount" => 1_234_567.89 })).to eq('{"amount":1234567.89}')
    end

    it "escapes slashes on demand" do
      expect(described_class.json_encode({ "DT" => "12/25" }, escape_slashes: true)).to eq('{"DT":"12\\/25"}')
    end
  end

  describe ".raw_url_encode" do
    it "matches PHP rawurlencode" do
      expect(described_class.raw_url_encode("tx 1/2")).to eq("tx%201%2F2")
      expect(described_class.raw_url_encode("abc-_.~")).to eq("abc-_.~")
      expect(described_class.raw_url_encode("ĄĘ")).to eq("%C4%84%C4%98")
    end
  end
end
