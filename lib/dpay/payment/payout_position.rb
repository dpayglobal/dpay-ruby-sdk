# frozen_string_literal: true

module DPay
  class PayoutPosition
    attr_reader :iban, :title, :amount

    def initialize(iban, title, amount)
      raise InvalidArgumentError, "Payout IBAN must not be empty" unless iban.is_a?(String) && !iban.empty?
      unless title.is_a?(String) && !title.empty? && title.length <= 255
        raise InvalidArgumentError, "Payout title must be 1-255 characters"
      end

      @iban = iban
      @title = title
      @amount = amount
      freeze
    end

    def to_h
      { "iban" => @iban, "title" => @title, "amount" => @amount.to_decimal.to_f }
    end
  end
end
