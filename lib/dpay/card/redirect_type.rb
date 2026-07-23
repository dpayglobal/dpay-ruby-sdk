# frozen_string_literal: true

module DPay
  module RedirectType
    SUCCESS = "SUCCESS"
    FORM = "FORM"
    URL = "URL"
    DCC_OFFER = "DCC_OFFER"

    ALL = [SUCCESS, FORM, URL, DCC_OFFER].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid redirect type "#{value}") unless valid?(value)
    end
  end
end
