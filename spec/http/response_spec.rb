# frozen_string_literal: true

RSpec.describe DPay::HTTP::Response do
  it "looks up headers case insensitively" do
    response = described_class.new(429, { "Retry-After" => "30", "X-RateLimit-Limit" => "120" }, "{}")

    expect(response.header("retry-after")).to eq("30")
    expect(response.header("X-RATELIMIT-LIMIT")).to eq("120")
    expect(response.header("missing")).to be_nil
  end

  it "decodes JSON objects and arrays" do
    expect(described_class.new(200, {}, '{"status":"success"}').decode_json).to eq({ "status" => "success" })
    expect(described_class.new(200, {}, '[{"id":"1"}]').decode_json).to eq([{ "id" => "1" }])
  end

  it "returns nil for anything that is not a JSON object or array" do
    expect(described_class.new(200, {}, "not-json").decode_json).to be_nil
    expect(described_class.new(200, {}, '"scalar"').decode_json).to be_nil
    expect(described_class.new(200, {}, "").decode_json).to be_nil
  end
end
