# frozen_string_literal: true

module DPay
  class CardRecurringRegistration
    DATE = /\A\d{4}-\d{2}-\d{2}\z/

    def self.create(label)
      new(label)
    end

    def initialize(label)
      unless label.is_a?(String) && !label.empty? && label.length <= 50
        raise InvalidArgumentError, "Mandate label must be 1-50 characters"
      end

      @label = label
      @optional = {}
    end

    def with_frequency(frequency)
      CardRecurringFrequency.assert_valid(frequency)
      @optional["frequency"] = frequency
      self
    end

    def with_limit_amt(limit_amt)
      @optional["limit_amt"] = limit_amt.minor
      self
    end

    def with_tot_limit_amt(tot_limit_amt)
      @optional["tot_limit_amt"] = tot_limit_amt.minor
      self
    end

    def with_limit_amt_fixed(fixed)
      @optional["is_limit_amt_fixed"] = fixed
      self
    end

    def with_expiration_date(expiration_date)
      @optional["expiration_date"] = assert_date(expiration_date)
      self
    end

    def with_init_date(init_date)
      @optional["init_date"] = assert_date(init_date)
      self
    end

    def to_h
      base = { "label" => @label }

      %w[frequency limit_amt tot_limit_amt is_limit_amt_fixed expiration_date init_date].each do |key|
        base[key] = @optional[key] if @optional.key?(key)
      end

      base
    end

    private

    def assert_date(date)
      raise InvalidArgumentError, %(Date "#{date}" must be in YYYY-MM-DD format) unless DATE.match?(date.to_s)

      date
    end
  end
end
