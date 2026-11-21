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

  describe "alias_update" do
    let(:secret) { "secret123" }
    let(:payment_id) { "30D9493D-1D73-3FBD-A5D4-633723CC7A68" }
    let(:transfer) do
      { "id" => "tx-1", "amount" => "29.99", "email" => "jan@example.com", "type" => "transfer", "attempt" => 1,
        "version" => 2, "custom" => "order-1" }
    end

    def alias_update(overrides = {})
      payload = {
        "id" => payment_id, "type" => "alias_update", "change_type" => "ALIAS_UNREGISTER", "alias_type" => "UID",
        "alias_status" => "UNREGISTERED", "alias_label" => "Moj sklep", "alias_key" => "KEY-1",
        "alias_expire_at" => nil, "change_reason_category" => "USER",
        "change_reason_message" => "Unregistered in the banking app", "version" => 1
      }.merge(overrides)
      payload["signature"] ||= Digest::SHA256.hexdigest("#{payment_id}#{secret}alias_update1")
      JSON.generate(payload)
    end

    def signed_transfer(overrides = {})
      parts = [transfer["id"], secret, transfer["amount"], transfer["email"], transfer["type"], transfer["attempt"],
               transfer["version"], transfer["custom"]]
      transfer.merge("signature" => Digest::SHA256.hexdigest(parts.join)).merge(overrides)
    end

    it "verifies sha256(id + hash + type + version) and exposes the alias change" do
      event = described_class.construct_event(alias_update, secret)
      change = event.alias_update

      expect(event).to be_alias_update
      expect(event).not_to be_transfer
      expect(event.id).to eq(payment_id)
      expect(event.amount).to eq("")
      expect(change.change_type).to eq(DPay::AliasUpdate::CHANGE_UNREGISTER)
      expect(change.alias_type).to eq(DPay::AliasUpdate::ALIAS_TYPE_UID)
      expect(change.alias_status).to eq(DPay::AliasUpdate::STATUS_UNREGISTERED)
      expect(change).not_to be_active
      expect(change.alias_key).to eq("KEY-1")
      expect(change.alias_label).to eq("Moj sklep")
      expect(change.alias_expire_at).to be_nil
    end

    it "reads the reason of the alias change" do
      change = described_class.construct_event(alias_update, secret).alias_update

      expect(change.change_reason_category).to eq("USER")
      expect(change.change_reason_message).to eq("Unregistered in the banking app")
      expect(change.raw["alias_key"]).to eq("KEY-1")
    end

    it "does not sign the alias fields, only id, type and version" do
      expect(described_class.construct_event(alias_update("alias_status" => "ACTIVE"), secret).alias_update)
        .to be_active

      expect { described_class.construct_event(alias_update("id" => "OTHER"), secret) }
        .to raise_error(DPay::SignatureVerificationError, "Invalid IPN signature")
    end

    it "requires a version" do
      expect { described_class.construct_event(alias_update("version" => nil), secret) }
        .to raise_error(DPay::SignatureVerificationError, "Invalid IPN payload")
    end

    it "ignores the unsigned transfer fields" do
      event = described_class.construct_event(
        alias_update("amount" => "999.00", "email" => "attacker@example.com", "attempt" => 7, "custom" => "order-1234"),
        secret
      )

      expect(event).to be_alias_update
      expect(event.amount).to eq("")
      expect(event.email).to be_nil
      expect(event.attempt).to eq(0)
      expect(event.custom).to be_nil
      expect(event.id).to eq(payment_id)
      expect(event.version).to eq(1)
    end

    it "does not verify a transfer signature as alias_update or the reverse" do
      expect { verify(signed_transfer("type" => "alias_update")) }
        .to raise_error(DPay::SignatureVerificationError, "Invalid IPN signature")
      expect do
        described_class.construct_event(alias_update("type" => "transfer", "amount" => "", "attempt" => 1), secret)
      end.to raise_error(DPay::SignatureVerificationError, "Invalid IPN signature")
    end

    it "has no alias change for other types" do
      event = verify(signed_transfer)

      expect(event).not_to be_alias_update
      expect(event.alias_update).to be_nil
      expect(DPay::IpnType::ALL).to include(DPay::IpnType::ALIAS_UPDATE)
    end

    it "signs a non-numeric version as 0 like the PHP SDK" do
      body = alias_update("version" => "v1", "signature" => Digest::SHA256.hexdigest("#{payment_id}#{secret}alias_update0"))

      expect(described_class.construct_event(body, secret).version).to eq(0)
    end
  end
end
