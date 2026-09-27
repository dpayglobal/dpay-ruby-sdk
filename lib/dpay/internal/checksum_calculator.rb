# frozen_string_literal: true

require "digest"

module DPay
  module Internal
    class ChecksumCalculator
      CHECKSUM_KEY = "checksum"

      def initialize(secret_hash)
        @secret_hash = secret_hash
        freeze
      end

      # sha256(service|secret_hash|field1|field2|...) - payment registration, BLIK aliases, recurring payments, events.
      def secret_second(service, fields)
        parts = [service, @secret_hash] + fields.map { |field| PHP.strval(field) }

        Digest::SHA256.hexdigest(parts.join("|"))
      end

      # sha256(value1|value2|...|secret_hash) over the request body in the order it is sent (PBL API: refunds,
      # transaction details, banks, payouts). Takes the whole body (Hash) or its values (Array). The "checksum" key
      # is skipped, nested objects (e.g. "webhook") contribute their leaf values in order, nil and false give an empty
      # segment and true gives "1" - the way the API casts JSON values to strings.
      def ordered_body(body)
        values = body.is_a?(Hash) ? body.reject { |key, _| key.to_s == CHECKSUM_KEY }.values : body
        joined = values.flat_map { |value| leaves(value) }.map { |leaf| PHP.strval(leaf) }.join("|")

        Digest::SHA256.hexdigest("#{joined}|#{@secret_hash}")
      end

      # sha256(operation|service|transaction_id|amount|secret_hash) - Cards API capture and cancellation. The
      # operation name keeps a capture checksum from authorising a cancellation; without an amount the segment
      # stays empty.
      def operation(operation, service, transaction_id, amount)
        Digest::SHA256.hexdigest([operation, service, transaction_id, amount || "", @secret_hash].join("|"))
      end

      private

      def leaves(value)
        case value
        when Hash then value.values.flat_map { |item| leaves(item) }
        when Array then value.flat_map { |item| leaves(item) }
        else [value]
        end
      end
    end
  end
end
