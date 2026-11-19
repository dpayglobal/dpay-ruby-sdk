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

    # Payment ID - for alias_update the payment that registered the alias.
    def id
      scalar("id") || ""
    end

    # Paid amount as sent (e.g. "10.00"); empty for alias_update - its signature does not cover an amount, so a value
    # in the payload is ignored.
    def amount
      alias_update? ? "" : scalar("amount") || ""
    end

    def type
      scalar("type") || ""
    end

    def signature
      scalar("signature") || ""
    end

    # Payer's email; nil for alias_update (not signed there).
    def email
      alias_update? ? nil : scalar("email")
    end

    # The custom value of the registration; nil for alias_update (not signed there).
    def custom
      alias_update? ? nil : scalar("custom")
    end

    # @deprecated dpay no longer sends capture IPNs - use the "payment.captured" webhook event.
    def capture_payment_id
      scalar("capture_payment_id")
    end

    # Delivery attempt; 0 for alias_update (not signed there).
    def attempt
      alias_update? ? 0 : integer("attempt")
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

    # BLIK OneClick alias or recurring payment status change - details in #alias_update.
    def alias_update?
      type == IpnType::ALIAS_UPDATE
    end

    # Alias change of an alias_update IPN (DPay::AliasUpdate); nil for other types.
    def alias_update
      alias_update? ? AliasUpdate.from_api(@raw) : nil
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
