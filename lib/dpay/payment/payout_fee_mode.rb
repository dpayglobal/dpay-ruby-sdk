# frozen_string_literal: true

module DPay
  module PayoutFeeMode
    NET = "net"
    GROSS = "gross"

    ALL = [NET, GROSS].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid payout fee mode "#{value}") unless valid?(value)
    end
  end
end
