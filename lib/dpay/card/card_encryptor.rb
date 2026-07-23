# frozen_string_literal: true

require "openssl"

module DPay
  class CardEncryptor
    def encrypt(card, transaction_id, public_key_pem, timestamp: Time.now.to_i)
      key = load_key(public_key_pem)
      payload = Internal::PHP.json_encode(
        { "PN" => card.pan, "SC" => card.cvv, "DT" => card.expiry, "ID" => transaction_id, "TX" => timestamp },
        escape_slashes: true
      )

      [key.public_encrypt(payload, OpenSSL::PKey::RSA::PKCS1_PADDING)].pack("m0")
    rescue OpenSSL::PKey::PKeyError => e
      raise CardEncryptionError, "Card data encryption failed: #{e.message}"
    end

    private

    def load_key(public_key_pem)
      OpenSSL::PKey::RSA.new(public_key_pem.to_s)
    rescue OpenSSL::PKey::PKeyError, ArgumentError, TypeError
      raise CardEncryptionError, "Invalid RSA public key"
    end
  end
end
