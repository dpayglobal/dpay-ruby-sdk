# frozen_string_literal: true

require "openssl"

RSpec.describe DPay::CardEncryptor do
  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:card) { DPay::CardData.new("4111 1111 1111 1111", "123", "12/25") }

  it "produces the golden card payload under RSA PKCS#1 v1.5" do
    encrypted = described_class.new.encrypt(card, "tx-1", key.public_key.to_pem, timestamp: 1_784_700_000)

    decrypted = key.private_decrypt(encrypted.unpack1("m0"), OpenSSL::PKey::RSA::PKCS1_PADDING)

    expect(decrypted).to eq('{"PN":"4111111111111111","SC":"123","DT":"12\\/25","ID":"tx-1","TX":1784700000}')
  end

  it "strips spaces from the PAN and validates card data" do
    expect(card.pan).to eq("4111111111111111")
    expect { DPay::CardData.new("41111", "123", "12/25") }.to raise_error(DPay::InvalidArgumentError)
    expect { DPay::CardData.new("4111111111111111", "12", "12/25") }.to raise_error(DPay::InvalidArgumentError)
    expect { DPay::CardData.new("4111111111111111", "123", "13/25") }.to raise_error(DPay::InvalidArgumentError)
    expect { DPay::CardData.new("4111111111111111", "123", "2025-12") }.to raise_error(DPay::InvalidArgumentError)
  end

  it "raises on an invalid public key" do
    expect { described_class.new.encrypt(card, "tx-1", "not-a-key") }
      .to raise_error(DPay::CardEncryptionError, "Invalid RSA public key")
  end

  it "keeps card data out of inspect output" do
    expect(card.inspect).not_to include("4111")
    expect(card.inspect).not_to include("123")
    expect(card.to_s).not_to include("4111")
    expect(card.inspect).to include("[FILTERED]")
  end
end
