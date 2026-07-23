# frozen_string_literal: true

module DPay
  class Money
    DECIMAL = /\A(-?)(\d+)(?:\.(\d{1,2}))?\z/

    attr_reader :minor, :currency

    def self.pln(minor)
      new(minor, Currency::PLN)
    end

    def self.of(minor, currency)
      Currency.assert_valid(currency)
      new(minor, currency)
    end

    def self.from_decimal(decimal, currency)
      Currency.assert_valid(currency)
      parsed = parse_decimal(decimal)
      raise InvalidArgumentError, %(Invalid money amount "#{decimal}") if parsed.nil?

      new(parsed, currency)
    end

    def self.from_api_number(value, currency)
      case value
      when Integer then of(value * 100, currency)
      when Float then of(Internal::PHP.round(value * 100), currency)
      when String then from_decimal(value, currency)
      else raise InvalidArgumentError, "Money value must be Integer, Float or String"
      end
    end

    def self.try_from_api_number(value, currency)
      return nil unless Currency.valid?(currency)

      case value
      when Integer then new(value * 100, currency)
      when Float then new(Internal::PHP.round(value * 100), currency)
      when String
        parsed = parse_decimal(value)
        parsed.nil? ? nil : new(parsed, currency)
      end
    end

    def self.parse_decimal(decimal)
      match = DECIMAL.match(decimal.to_s)
      return nil if match.nil?

      minor = (match[2].to_i * 100) + (match[3] || "").ljust(2, "0").to_i
      match[1] == "-" ? -minor : minor
    end
    private_class_method :parse_decimal

    def initialize(minor, currency)
      @minor = minor
      @currency = currency
      freeze
    end

    def to_decimal
      absolute = @minor.abs
      sign = @minor.negative? ? "-" : ""
      format("%<sign>s%<dollars>d.%<cents>02d", sign: sign, dollars: absolute / 100, cents: absolute % 100)
    end

    def negative?
      @minor.negative?
    end

    def ==(other)
      other.is_a?(Money) && other.minor == @minor && other.currency == @currency
    end
    alias eql? ==

    def hash
      [@minor, @currency].hash
    end

    def to_s
      "#{to_decimal} #{@currency}"
    end
  end
end
