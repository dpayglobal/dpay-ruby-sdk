# frozen_string_literal: true

module DPay
  class CardData
    PAN = /\A\d{12,19}\z/
    CVV = /\A\d{3,4}\z/
    EXPIRY = %r{\A(0[1-9]|1[0-2])/\d{2}\z}

    attr_reader :pan, :cvv, :expiry

    def initialize(pan, cvv, expiry)
      normalized = pan.to_s.delete(" ")

      raise InvalidArgumentError, "Card number must be 12-19 digits" unless PAN.match?(normalized)
      raise InvalidArgumentError, "CVV must be 3-4 digits" unless CVV.match?(cvv.to_s)
      raise InvalidArgumentError, "Expiry must be in MM/YY format" unless EXPIRY.match?(expiry.to_s)

      @pan = normalized
      @cvv = cvv
      @expiry = expiry
      freeze
    end

    def inspect
      "#<DPay::CardData pan=[FILTERED] cvv=[FILTERED] expiry=[FILTERED]>"
    end

    alias to_s inspect
  end
end
