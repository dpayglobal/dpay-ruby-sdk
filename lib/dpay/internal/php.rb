# frozen_string_literal: true

require "json"

module DPay
  module Internal
    module PHP
      SAFE_INTEGRAL_FLOAT = 2**53
      NON_UNRESERVED = /[^A-Za-z0-9\-_.~]/n

      module_function

      def strval(value)
        case value
        when nil, false then ""
        when true then "1"
        when Float then float_to_string(value)
        when String then value
        else value.to_s
        end
      end

      def round(value)
        value >= 0 ? (value + 0.5).floor : (value - 0.5).ceil
      end

      def json_encode(data, escape_slashes: false)
        encoded = JSON.generate(normalize_floats(data))
        escape_slashes ? encoded.gsub("/") { "\\/" } : encoded
      end

      def raw_url_encode(value)
        value.to_s.b.gsub(NON_UNRESERVED) { |byte| format("%%%02X", byte.ord) }
      end

      def float_to_string(value)
        return "NAN" if value.nan?
        return value.positive? ? "INF" : "-INF" if value.infinite?

        formatted = format("%.14G", value)
        return formatted unless formatted.include?("E")

        parts = formatted.split("E")
        mantissa = parts.fetch(0)
        exponent = parts.fetch(1)
        mantissa += ".0" unless mantissa.include?(".")
        sign = exponent.start_with?("-") ? "-" : "+"
        digits = exponent.sub(/\A[+-]/, "").sub(/\A0+/, "")
        digits = "0" if digits.empty?
        "#{mantissa}E#{sign}#{digits}"
      end

      def normalize_floats(value)
        case value
        when Float
          integral_float?(value) ? value.to_i : value
        when Hash
          value.each_with_object({}) { |(key, item), result| result[key] = normalize_floats(item) }
        when Array
          value.map { |item| normalize_floats(item) }
        else
          value
        end
      end

      def integral_float?(value)
        value.finite? && value.abs < SAFE_INTEGRAL_FLOAT && value.to_i == value
      end
    end
  end
end
