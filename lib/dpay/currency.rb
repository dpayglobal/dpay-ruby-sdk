# frozen_string_literal: true

module DPay
  module Currency
    PLN = "PLN"
    EUR = "EUR"
    CZK = "CZK"

    CODE = /\A[A-Z]{3}\z/

    def self.valid?(code)
      code.is_a?(String) && CODE.match?(code)
    end

    def self.assert_valid(code)
      raise InvalidArgumentError, %(Invalid currency code "#{code}") unless valid?(code)
    end
  end
end
