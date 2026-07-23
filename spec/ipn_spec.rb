# frozen_string_literal: true

RSpec.describe DPay::IpnVerifier do
  let(:secret) { "sekret-hash-123" }

  def verify(payload)
    described_class.construct_event(JSON.generate(payload), secret)
  end

  it "accepts a transfer signature" do
    event = verify(
      "id" => "tx-1", "amount" => "29.99", "email" => "jan@example.com", "type" => "transfer",
      "attempt" => 1, "version" => 2, "custom" => "order-1",
      "signature" => "6493bb71d07d0cfee9ee0eea8f6af2a40beaac8b7e7b6b0b6d4b29e35801dd9d"
    )

    expect(event.id).to eq("tx-1")
    expect(event.amount).to eq("29.99")
    expect(event.email).to eq("jan@example.com")
    expect(event.attempt).to eq(1)
    expect(event.version).to eq(2)
    expect(event.custom).to eq("order-1")
    expect(event).to be_transfer
    expect(event).not_to be_capture
  end

  it "omits email from the DCB signature" do
    event = verify(
      "id" => "tx-2", "amount" => "10.50", "type" => "dcb", "attempt" => 3, "version" => 1,
      "signature" => "e933e4cb4c32edf4062d12bb62cd6f549efa2fbb81327d1970174a239c421bf2"
    )

    expect(event).to be_dcb
    expect(event.email).to be_nil
  end

  it "accepts a capture signature with a float amount and string counters" do
    event = verify(
      "id" => "tx-3", "amount" => 10.5, "email" => "", "type" => "capture", "attempt" => "1",
      "version" => "1", "custom" => "", "capture_payment_id" => "cap-9",
      "signature" => "b1a6bc1f7721123236547b97eeb55e2a770f748a87cc2fffedd43d69510f5bd0"
    )

    expect(event).to be_capture
    expect(event.amount).to eq("10.5")
    expect(event.capture_payment_id).to eq("cap-9")
  end

  it "accepts numeric id and integer amount" do
    event = verify(
      "id" => 4, "amount" => 10, "type" => "transfer", "attempt" => 1, "version" => 1,
      "signature" => "e8160e4f5d0e4d99da36205ca07eeeb487e97166048287c8550e0e7e67306f13"
    )

    expect(event.id).to eq("4")
    expect(event.amount).to eq("10")
  end

  it "rejects a tampered signature" do
    expect do
      verify("id" => "tx-1", "amount" => "29.99", "email" => "jan@example.com", "type" => "transfer",
             "attempt" => 1, "version" => 2, "custom" => "order-1", "signature" => "0" * 64)
    end.to raise_error(DPay::SignatureVerificationError, "Invalid IPN signature")
  end

  it "rejects a wrong secret" do
    payload = JSON.generate(
      "id" => "tx-1", "amount" => "29.99", "email" => "jan@example.com", "type" => "transfer",
      "attempt" => 1, "version" => 2, "custom" => "order-1",
      "signature" => "6493bb71d07d0cfee9ee0eea8f6af2a40beaac8b7e7b6b0b6d4b29e35801dd9d"
    )

    expect { described_class.construct_event(payload, "wrong-secret") }
      .to raise_error(DPay::SignatureVerificationError, "Invalid IPN signature")
  end

  it "rejects malformed payloads" do
    payloads = [
      "{oops",
      "[1,2]",
      '{"id":"x"}',
      '{"id":null,"amount":"1","type":"transfer","attempt":1,"version":1,"signature":"x"}'
    ]
    payloads.each do |body|
      expect { described_class.construct_event(body, secret) }
        .to raise_error(DPay::SignatureVerificationError, "Invalid IPN payload")
    end
  end

  it "rejects a signature of the wrong length" do
    expect do
      verify("id" => "tx-1", "amount" => "29.99", "email" => "jan@example.com", "type" => "transfer",
             "attempt" => 1, "version" => 2, "custom" => "order-1", "signature" => "abc")
    end.to raise_error(DPay::SignatureVerificationError, "Invalid IPN signature")
  end

  it "exposes the exact acknowledgement body" do
    expect(DPay::IpnEvent::ACK).to eq("OK")
  end
end
