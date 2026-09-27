# frozen_string_literal: true

module DPay
  module BlikAliasType
    # BLIK OneClick alias. Recurring payments (PAYID) are handled by Client#recurring.
    UID = "UID"

    ALL = [UID].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid BLIK alias type "#{value}") unless valid?(value)
    end
  end
end
