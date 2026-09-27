# frozen_string_literal: true

require "json"
require "openssl"

module DPay
  # Verifies dpay webhooks (Standard Webhooks):
  # "webhook-signature" = "v1," + base64(HMAC-SHA256(key, id.timestamp.body)), where the key is the base64-decoded
  # secret without the "whsec_" prefix. During a secret rotation dpay sends two signatures separated by a space -
  # one match is enough.
  module WebhookVerifier
    DEFAULT_TOLERANCE = 300
    SECRET_PREFIX = "whsec_"
    SIGNATURE_VERSION = "v1"
    ID_HEADER = "webhook-id"
    TIMESTAMP_HEADER = "webhook-timestamp"
    SIGNATURE_HEADER = "webhook-signature"
    RACK_PREFIX = "http-"
    TIMESTAMP = /\A\d+\z/
    BASE64 = %r{\A([A-Za-z0-9+/]*)(=*)\z}
    BASE64_WHITESPACE = " \t\r\n"
    INVALID_SECRET = "Webhook secret must be the whsec_ value from the dpay panel"

    module_function

    # Verifies the signature and returns the event. Pass the raw request body exactly as received. headers: Hash
    # (or anything with #each yielding name and value) with String or Symbol names in any letter case, also in
    # the Rack format (HTTP_WEBHOOK_ID); a value may be an Array (the first element counts). secrets: the "whsec_..."
    # secret or an Array of secrets during a rotation.
    def construct_event(raw_body, headers, secrets, tolerance = DEFAULT_TOLERANCE, now = nil)
      verify(raw_body, headers, secrets, tolerance, now)

      payload = begin
        JSON.parse(raw_body.to_s)
      rescue JSON::ParserError
        nil
      end
      raise SignatureVerificationError, "Invalid webhook payload" unless payload.is_a?(Hash)

      WebhookEvent.from_api(payload)
    end

    def verify(raw_body, headers, secrets, tolerance = DEFAULT_TOLERANCE, now = nil)
      id = header(headers, ID_HEADER)
      timestamp = header(headers, TIMESTAMP_HEADER)
      signature = header(headers, SIGNATURE_HEADER)
      if id.nil? || timestamp.nil? || signature.nil?
        raise SignatureVerificationError, "Missing webhook-id, webhook-timestamp or webhook-signature header"
      end
      raise SignatureVerificationError, "Invalid webhook-timestamp header" unless TIMESTAMP.match?(timestamp)
      if ((now || Time.now.to_i) - timestamp.to_i).abs > tolerance
        raise SignatureVerificationError, "Webhook timestamp is outside the tolerance zone"
      end

      signed = "#{id}.#{timestamp}.".b + raw_body.to_s.b
      expected = (secrets.is_a?(Array) ? secrets : [secrets]).map do |secret|
        OpenSSL::HMAC.base64digest("SHA256", key(secret), signed)
      end
      return nil if signature_matches?(signature, expected)

      raise SignatureVerificationError, "No valid webhook signature found"
    end

    def header(headers, name)
      headers.each do |key, value|
        next unless header_name(key) == name

        value = value.first if value.is_a?(Array)
        return value.is_a?(String) && !value.empty? ? value : nil
      end

      nil
    end

    def header_name(key)
      key.to_s.downcase.tr("_", "-").delete_prefix(RACK_PREFIX)
    end

    def signature_matches?(header_value, expected)
      header_value.strip.split(/\s+/).any? do |entry|
        version, value = entry.split(",", 2)
        next false unless version == SIGNATURE_VERSION && value.is_a?(String)

        expected.any? { |candidate| secure_compare(candidate, value) }
      end
    end

    def secure_compare(expected, actual)
      expected.bytesize == actual.bytesize && OpenSSL.fixed_length_secure_compare(expected, actual)
    end

    # Decodes the secret like PHP base64_decode($secret, true): whitespace is skipped, the padding may be missing,
    # any other character outside the alphabet makes the secret invalid.
    def key(secret)
      raise InvalidArgumentError, INVALID_SECRET unless secret.is_a?(String)

      match = BASE64.match(secret.delete_prefix(SECRET_PREFIX).delete(BASE64_WHITESPACE))
      data = match.nil? ? "" : match[1].to_s
      padding = match.nil? ? "" : match[2].to_s
      if data.empty? || data.length % 4 == 1 || padding.length > 2 ||
         (!padding.empty? && (data.length + padding.length) % 4 != 0)
        raise InvalidArgumentError, INVALID_SECRET
      end

      "#{data}#{"=" * (-data.length % 4)}".unpack1("m").to_s
    end

    private_class_method :header, :header_name, :signature_matches?, :secure_compare, :key
  end
end
