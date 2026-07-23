# frozen_string_literal: true

require "digest"

module DPay
  module Internal
    class ChecksumCalculator
      def initialize(secret_hash)
        @secret_hash = secret_hash
        freeze
      end

      def secret_second(service, fields)
        parts = [service, @secret_hash] + fields.map { |field| PHP.strval(field) }

        Digest::SHA256.hexdigest(parts.join("|"))
      end

      def ordered_body(values)
        joined = values.map { |value| PHP.strval(value) }.join("|")

        Digest::SHA256.hexdigest("#{joined}|#{@secret_hash}")
      end
    end
  end
end
