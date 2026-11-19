# frozen_string_literal: true

module DPay
  # Payout "state": 0 waiting, 1 processed, -1 failure.
  module PayoutState
    WAITING = 0
    PROCESSED = 1
    FAILED = -1

    ALL = [WAITING, PROCESSED, FAILED].freeze

    def self.valid?(value)
      value.is_a?(Integer) && ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid payout state "#{value}") unless valid?(value)
    end
  end
end
