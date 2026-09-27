# frozen_string_literal: true

require "digest"

# Shared checksum vectors of all dpay SDKs (spec/fixtures/api_vectors.json, synthetic data computed with the API code).
RSpec.describe "Shared API vectors" do
  let(:vectors) { ApiVectors.data }
  let(:calculator) { DPay::Internal::ChecksumCalculator.new(vectors["secret_hash"]) }

  it "matches the secret_second vectors" do
    vectors["secret_second"].each do |vector|
      expect(calculator.secret_second(vectors["service"], vector["fields"]))
        .to eq(vector["checksum"]), vector["name"]
    end
  end

  it "matches the operation vectors" do
    vectors["operation"].each do |vector|
      checksum = calculator.operation(vector["operation"], vectors["service"], vectors["transaction_id"],
                                      vector["amount"])

      expect(checksum).to eq(vector["checksum"]), vector["name"]
    end
  end

  it "matches the ordered_body vectors" do
    vectors["ordered_body"].each do |vector|
      expect(calculator.ordered_body(vector["body"])).to eq(vector["checksum"]), vector["name"]
    end
  end

  it "skips the checksum key and casts values like the API" do
    calculator = DPay::Internal::ChecksumCalculator.new("h")
    body = { "x" => "a", "checksum" => "ignored", "y" => true, "z" => nil, "w" => { "v" => "b" } }

    expect(calculator.ordered_body(body)).to eq(Digest::SHA256.hexdigest("a|1||b|h"))
    expect(calculator.ordered_body({ x: "a", checksum: "ignored", w: ["b", false, 15.0] }))
      .to eq(Digest::SHA256.hexdigest("a|b||15|h"))
  end

  it "keeps accepting the body values as a list" do
    expect(calculator.ordered_body(vectors["ordered_body"][1]["body"].values))
      .to eq(vectors["ordered_body"][1]["checksum"])
  end
end
