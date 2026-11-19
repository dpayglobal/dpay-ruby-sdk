# frozen_string_literal: true

module DPay
  # Multibanco payment reference returned by the registration ("multibanco"): the payer pays it at an ATM or in online
  # banking with the entity and reference numbers, so you can show them without redirecting to the gateway.
  class MultibancoReference
    # entity: entity number (5 digits). reference: reference number (9 digits, without spaces).
    # amount: amount to pay in #currency (EUR). expires_at: expiry in UTC, ISO 8601 (e.g. "2026-11-21T10:00:00+00:00").
    attr_reader :entity, :reference, :amount, :currency, :expires_at, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @entity = string(data["entity"]) || ""
      @reference = string(data["reference"]) || ""
      currency = string(data["currency"])
      @currency = !currency.nil? && Currency.valid?(currency) ? currency : Currency::EUR
      @amount = Money.try_from_api_number(data["amount"], @currency)
      @expires_at = string(data["expires_at"])
      freeze
    end

    private

    def string(value)
      value.is_a?(String) || value.is_a?(Integer) ? value.to_s : nil
    end
  end
end
