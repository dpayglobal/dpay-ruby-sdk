# frozen_string_literal: true

module DPay
  module CardRecurringOperation
    ADD_CARD = "add_card"
    COF_INITIAL = "cof_initial"
    CHARGE = "charge"

    ALL = [ADD_CARD, COF_INITIAL, CHARGE].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid card recurring operation "#{value}") unless valid?(value)
    end
  end
end
