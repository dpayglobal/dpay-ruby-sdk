# frozen_string_literal: true

module DPay
  module Internal
    # Readers shared by the webhook object models and payout models.
    module ObjectFields
      module_function

      # String, or an Integer as its decimal string; nil otherwise.
      def string(data, key)
        value = data[key]
        value.is_a?(String) || value.is_a?(Integer) ? value.to_s : nil
      end

      def integer_or_nil(data, key)
        value = data[key]
        value.is_a?(Integer) ? value : nil
      end

      def hash_or_nil(data, key)
        value = data[key]
        value.is_a?(Hash) ? value : nil
      end

      # Currency code of the object, PLN when missing or invalid.
      def currency(data, key = "currency")
        value = data[key]
        value.is_a?(String) && Currency.valid?(value) ? value : Currency::PLN
      end

      # Amount in minor units (an Integer in the payload); 0 when missing.
      def money(data, key, currency)
        minor = data[key]
        Money.of(minor.is_a?(Integer) ? minor : 0, currency)
      end
    end
  end
end
