# frozen_string_literal: true

module DPay
  module TransactionType
    TRANSFERS = "transfers"
    DCB_GATEWAY = "dcb_gateway"
    CARD_AUTH = "card_auth"
    MB_WAY_DIRECT = "mb_way_direct"
    BIZUM_DIRECT = "bizum_direct"
    BLIK_RECURRING = "blik_recurring"
    CARD_RECURRING = "card_recurring"

    ALL = [TRANSFERS, DCB_GATEWAY, CARD_AUTH, MB_WAY_DIRECT, BIZUM_DIRECT, BLIK_RECURRING, CARD_RECURRING].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid transaction type "#{value}") unless valid?(value)
    end
  end
end
