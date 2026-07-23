# frozen_string_literal: true

module DPay
  module BlikAliasType
    UID = "UID"
    PAYID = "PAYID"

    ALL = [UID, PAYID].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid BLIK alias type "#{value}") unless valid?(value)
    end
  end
end
