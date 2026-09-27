# frozen_string_literal: true

module DPay
  class IpnEvent
    ACK = "OK"

    attr_reader :raw

    def self.from_verified_payload(payload)
      new(payload)
    end

    def initialize(payload)
      @raw = payload
      freeze
    end

    def id
      scalar("id") || ""
    end

    def amount
      scalar("amount") || ""
    end

    def type
      scalar("type") || ""
    end

    def signature
      scalar("signature") || ""
    end

    def email
      scalar("email")
    end

    def custom
      scalar("custom")
    end

    # @deprecated dpay no longer sends capture IPNs - use the "payment.captured" webhook event.
    def capture_payment_id
      scalar("capture_payment_id")
    end

    def attempt
      integer("attempt")
    end

    def version
      integer("version")
    end

    def transfer?
      type == IpnType::TRANSFER
    end

    # @deprecated dpay no longer sends capture IPNs - use the "payment.captured" webhook event.
    def capture?
      type == IpnType::CAPTURE
    end

    def dcb?
      type == IpnType::DCB
    end

    private

    def scalar(key)
      value = @raw[key]
      return nil unless value.is_a?(String) || value.is_a?(Numeric) ||
                        value.is_a?(TrueClass) || value.is_a?(FalseClass)

      Internal::PHP.strval(value)
    end

    def integer(key)
      value = @raw[key]
      return value.to_i if value.is_a?(Integer) || value.is_a?(Float)
      return value.to_i if value.is_a?(String) && /\A[+-]?\d+\z/.match?(value)

      0
    end
  end
end
