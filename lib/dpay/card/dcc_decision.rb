# frozen_string_literal: true

module DPay
  module DccDecision
    ACCEPT = "accept"
    REJECT = "reject"

    ALL = [ACCEPT, REJECT].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid DCC decision "#{value}") unless valid?(value)
    end
  end
end
