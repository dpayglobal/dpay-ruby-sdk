# frozen_string_literal: true

module DPay
  module CardRecurringFrequency
    DAILY = "DAILY"
    WEEKLY = "WEEKLY"
    BIWEEKLY = "BIWEEKLY"
    MONTHLY = "MONTHLY"
    QUARTERLY = "QUARTERLY"
    SEMIANNUAL = "SEMIANNUAL"
    ANNUAL = "ANNUAL"

    ALL = [DAILY, WEEKLY, BIWEEKLY, MONTHLY, QUARTERLY, SEMIANNUAL, ANNUAL].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid card recurring frequency "#{value}") unless valid?(value)
    end
  end
end
