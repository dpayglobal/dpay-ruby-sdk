# frozen_string_literal: true

module DPay
  module Internal
    module Coerce
      module_function

      def string(value)
        return nil unless value.is_a?(String) || value.is_a?(Numeric) ||
                          value.is_a?(TrueClass) || value.is_a?(FalseClass)

        PHP.strval(value)
      end

      # Decimal API amount in the given (valid) currency; 0 in that currency when missing or unparseable.
      def money(value, currency = Currency::PLN)
        Money.try_from_api_number(value.nil? ? 0 : value, currency) || Money.of(0, currency)
      end

      def boolean(value)
        return value if value.is_a?(TrueClass) || value.is_a?(FalseClass)
        return value != 0 if value.is_a?(Numeric)
        return !value.empty? && value != "0" if value.is_a?(String)

        false
      end

      def integer(value)
        return value.to_i if value.is_a?(Numeric)
        return value.to_i if value.is_a?(String) && /\A\s*[+-]?\d+/.match?(value)

        0
      end

      def optional_integer(value)
        return value.to_i if value.is_a?(Numeric)
        return value.to_i if value.is_a?(String) && /\A\s*[+-]?\d+\z/.match?(value)

        nil
      end

      def list(value)
        value.is_a?(Array) ? value.grep(Hash) : []
      end
    end
  end
end
