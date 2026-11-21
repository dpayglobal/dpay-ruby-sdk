# frozen_string_literal: true

module DPay
  module IpnType
    TRANSFER = "transfer"
    # @deprecated dpay no longer sends capture IPNs - use the "payment.captured" webhook event.
    CAPTURE = "capture"
    DCB = "dcb"
    # BLIK OneClick alias or recurring payment status change, sent to alias_ipn_url (or url_ipn).
    ALIAS_UPDATE = "alias_update"

    ALL = [TRANSFER, CAPTURE, DCB, ALIAS_UPDATE].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid IPN type "#{value}") unless valid?(value)
    end
  end
end
