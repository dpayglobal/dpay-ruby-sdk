# frozen_string_literal: true

module DPay
  class DccOffer
    attr_reader :currency_conversion_id, :original_amount, :converted_amount, :exchange_rate,
                :valid_until, :declaration_text, :markup, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @currency_conversion_id = Internal::Coerce.string(data["currencyConversionId"]) || ""
      @original_amount = Internal::Coerce.money(data["originalAmount"], currency(data["originalCurrency"]))
      @converted_amount = Internal::Coerce.money(data["convertedAmount"], currency(data["convertedCurrency"]))
      exchange_rate = data["exchangeRate"]
      @exchange_rate = exchange_rate.is_a?(Integer) || exchange_rate.is_a?(Float) ? exchange_rate.to_f : 0.0
      @valid_until = Internal::Coerce.string(data["validUntil"]) || ""
      @declaration_text = Internal::Coerce.string(data["declarationText"]) || ""
      @european_economic_area = Internal::Coerce.boolean(data["europeanEconomicArea"])
      @markup = Internal::Coerce.list(data["markup"]).map { |markup| DccMarkup.from_api(markup) }
      freeze
    end

    def european_economic_area?
      @european_economic_area
    end

    private

    def currency(value)
      Currency.valid?(value) ? value : Currency::PLN
    end
  end
end
