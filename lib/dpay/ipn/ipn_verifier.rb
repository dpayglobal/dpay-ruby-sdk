# frozen_string_literal: true

require "digest"
require "json"
require "openssl"

module DPay
  module IpnVerifier
    REQUIRED_FIELDS = %w[id amount type attempt version signature].freeze
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
      raise SignatureVerificationError, INVALID_PAYLOAD unless REQUIRED_FIELDS.all? { |f| !payload[f].nil? }

      payload
    end

    def expected_signature(payload, secret_hash)
      type = Internal::PHP.strval(payload["type"])

      parts = [Internal::PHP.strval(payload["id"]), secret_hash, Internal::PHP.strval(payload["amount"])]
      parts << Internal::PHP.strval(payload["email"]) unless type == IpnType::DCB
      parts << type
      parts << Internal::PHP.strval(payload["attempt"])
      parts << Internal::PHP.strval(payload["version"])
      parts << Internal::PHP.strval(payload["custom"])

      Digest::SHA256.hexdigest(parts.join)
    end

    def secure_compare(expected, actual)
      expected.bytesize == actual.bytesize && OpenSSL.fixed_length_secure_compare(expected, actual)
    end

    private_class_method :parse, :expected_signature, :secure_compare
  end
end
