# frozen_string_literal: true

module DPay
  class PayoutPosition
    POLISH_IBAN = /\APL\d{26}\z/

    attr_reader :iban, :title, :amount

    # iban: Polish IBAN of one of your verified bank accounts ("PL" + 26 digits, spaces allowed), sent as given.
    # amount: above 0.
    def initialize(iban, title, amount)
      unless self.class.valid_polish_iban?(iban)
        raise InvalidArgumentError, %(Payout IBAN "#{iban}" must be a valid Polish IBAN (PL + 26 digits))
      end
      unless title.is_a?(String) && !title.empty? && title.length <= 255
        raise InvalidArgumentError, "Payout title must be 1-255 characters"
      end
      raise InvalidArgumentError, "Payout amount must be above 0" unless amount.minor.positive?

      @iban = iban
      @title = title
      @amount = amount
      freeze
    end

    # "PL" + 26 digits after removing whitespace and upper-casing, with a valid ISO 13616 check (mod 97 = 1).
    def self.valid_polish_iban?(iban)
      return false unless iban.is_a?(String)

      normalized = iban.gsub(/\s/, "").upcase
      return false unless POLISH_IBAN.match?(normalized)

      # Country code and check digits go to the end, letters become numbers (P = 25, L = 21)
      numeric = "#{normalized[4..]}2521#{normalized[2, 2]}"
      numeric.scan(/.{1,7}/).reduce(0) { |remainder, chunk| "#{remainder}#{chunk}".to_i % 97 } == 1
    end

    def to_h
      { "iban" => @iban, "title" => @title, "amount" => @amount.to_decimal.to_f }
    end
  end
end
