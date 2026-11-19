# frozen_string_literal: true

require "digest"
require "json"
require "openssl"

module DPay
  # Verifies IPN notifications (JSON POST, acknowledged with the body "OK"):
  #  - transfer, dcb: sha256(id + SecretHash + amount + email + type + attempt + version + custom), dcb without email;
  #  - alias_update: sha256(id + SecretHash + type + version).
  module IpnVerifier
    REQUIRED_FIELDS = %w[id amount type attempt version signature].freeze
    ALIAS_UPDATE_REQUIRED_FIELDS = %w[id type version signature].freeze
    INVALID_PAYLOAD = "Invalid IPN payload"

    module_function

    def construct_event(raw_body, secret_hash)
      payload = parse(raw_body)
      signature = payload["signature"]
      raise SignatureVerificationError, INVALID_PAYLOAD unless signature.is_a?(String)

      expected = expected_signature(payload, secret_hash)
      raise SignatureVerificationError, "Invalid IPN signature" unless secure_compare(expected, signature)

      IpnEvent.from_verified_payload(payload)
    end

    def parse(raw_body)
      payload = begin
        JSON.parse(raw_body.to_s)
      rescue JSON::ParserError
        raise SignatureVerificationError, INVALID_PAYLOAD
      end

      raise SignatureVerificationError, INVALID_PAYLOAD unless payload.is_a?(Hash)

      required = scalar(payload["type"]) == IpnType::ALIAS_UPDATE ? ALIAS_UPDATE_REQUIRED_FIELDS : REQUIRED_FIELDS
      raise SignatureVerificationError, INVALID_PAYLOAD unless required.all? { |f| !payload[f].nil? }

      payload
    end

    def expected_signature(payload, secret_hash)
      type = scalar(payload["type"])
      id = scalar(payload["id"])
      version = numeric(payload["version"])

      parts = if type == IpnType::ALIAS_UPDATE
                [id, secret_hash, type, version]
              else
                transfer_parts(payload, id, secret_hash, type, version)
              end

      Digest::SHA256.hexdigest(parts.join)
    end

    def transfer_parts(payload, id, secret_hash, type, version)
      parts = [id, secret_hash, scalar(payload["amount"])]
      parts << scalar(payload["email"]) unless type == IpnType::DCB
      parts << type
      parts << numeric(payload["attempt"])
      parts << version
      parts << scalar(payload["custom"])
      parts
    end

    # PHP: is_scalar($value) ? (string) $value : ''
    def scalar(value)
      Internal::PHP.scalar?(value) ? Internal::PHP.strval(value) : ""
    end

    # PHP: is_numeric($value) ? (string) $value : '0'
    def numeric(value)
      Internal::PHP.numeric?(value) ? Internal::PHP.strval(value) : "0"
    end

    def secure_compare(expected, actual)
      expected.bytesize == actual.bytesize && OpenSSL.fixed_length_secure_compare(expected, actual)
    end

    private_class_method :parse, :expected_signature, :transfer_parts, :scalar, :numeric, :secure_compare
  end
end
