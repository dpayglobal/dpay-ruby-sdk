# frozen_string_literal: true

module DPay
  # Payout "type" in the payout list: "direct" covers exactly one payment (1:1 payout instruction, refund form payout).
  module PayoutType
    STANDARD = "standard"
    DIRECT = "direct"
    PAYSAFECARD = "paysafecard"

    ALL = [STANDARD, DIRECT, PAYSAFECARD].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid payout type "#{value}") unless valid?(value)
    end
  end
end
