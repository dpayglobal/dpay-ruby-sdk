# frozen_string_literal: true

module DPay
  # The "recurring_registration" object: registers a recurring payment (today BLIK, alias PAYID) together with a
  # payment that carries the customer's BLIK code. Models:
  #  - O (open): no frequency or limits, the merchant charges any amount within its active ranges (max 2000 PLN);
  #  - A (automatic): fixed amount, frequency, total limit, start and expiry date - all required;
  #  - M (manual): every charge is confirmed by the customer in the banking app; frequency and limits optional.
  class RecurringRegistration
    MODEL_A = "A"
    MODEL_M = "M"
    MODEL_O = "O"
    MODELS = [MODEL_A, MODEL_M, MODEL_O].freeze

    METHOD_BLIK = "blik"
    METHODS = [METHOD_BLIK].freeze

    FREQUENCY = /\A[1-9][0-9]{0,2}[DWMY]\z/
    DATE = /\A\d{4}-\d{2}-\d{2}\z/
    HTTP_URL = %r{\Ahttps?://[^\s]+\z}
    TERMS_URL_MAX = 2048
    ALIAS_MAX = 128
    MODEL_O_FORBIDDEN = %w[frequency limit_amt tot_limit_amt is_limit_amt_fixed].freeze
    MODEL_A_REQUIRED = %w[frequency limit_amt tot_limit_amt expiration_date init_date].freeze
    OPTIONAL_ORDER = %w[frequency limit_amt tot_limit_amt is_limit_amt_fixed expiration_date init_date methods].freeze

    attr_reader :model

    # terms_url: the merchant's terms the customer accepted (consent evidence).
    def self.create(label, model, terms_url)
      new(label, model, terms_url)
    end

    def initialize(label, model, terms_url)
      unless label.is_a?(String) && !label.empty? && label.length <= 50
        raise InvalidArgumentError, "Recurring payment label must be 1-50 characters"
      end
      raise InvalidArgumentError, %(Invalid recurring model "#{model}") unless MODELS.include?(model)
      unless terms_url.is_a?(String) && terms_url.bytesize <= TERMS_URL_MAX && HTTP_URL.match?(terms_url)
        raise InvalidArgumentError, %(Invalid terms URL "#{terms_url}")
      end

      @label = label
      @model = model
      @terms_url = terms_url
      @optional = {}
    end

    # Your own alias of the recurring payment (max 128 characters); without it dpay assigns one.
    def with_alias(alias_value)
      unless alias_value.is_a?(String) && !alias_value.empty? && alias_value.bytesize <= ALIAS_MAX
        raise InvalidArgumentError, "Recurring alias must be 1-128 characters"
      end

      set("alias", alias_value)
    end

    def with_terms_version(terms_version)
      unless terms_version.is_a?(String) && !terms_version.empty? && terms_version.length <= 64
        raise InvalidArgumentError, "Terms version must be 1-64 characters"
      end

      set("terms_version", terms_version)
    end

    # Payment methods of the recurring payment, today only "blik".
    def with_methods(names)
      unless names.is_a?(Array) && !names.empty? && names.uniq.size == names.size
        raise InvalidArgumentError, "Methods must be a non-empty list of distinct methods"
      end

      unsupported = names.reject { |name| METHODS.include?(name) }
      raise InvalidArgumentError, %(Unsupported recurring method "#{unsupported.first}") unless unsupported.empty?

      set("methods", names.dup)
    end

    # Frequency like "1M", "2W", "14D", "1Y" (1-999 days, weeks, months or years).
    def with_frequency(frequency)
      unless frequency.is_a?(String) && FREQUENCY.match?(frequency)
        raise InvalidArgumentError, %(Invalid recurring frequency "#{frequency}")
      end

      set("frequency", frequency)
    end

    # Single payment limit in minor units (grosz).
    def with_limit_amt(limit_amt)
      set("limit_amt", assert_positive(limit_amt, "limit_amt"))
    end

    # Total limit of all payments in minor units (grosz).
    def with_tot_limit_amt(tot_limit_amt)
      set("tot_limit_amt", assert_positive(tot_limit_amt, "tot_limit_amt"))
    end

    def with_limit_amt_fixed(fixed)
      raise InvalidArgumentError, "is_limit_amt_fixed must be true or false" unless [true, false].include?(fixed)

      set("is_limit_amt_fixed", fixed)
    end

    # YYYY-MM-DD, after today and at most 10 years ahead.
    def with_expiration_date(expiration_date)
      set("expiration_date", assert_date(expiration_date))
    end

    # YYYY-MM-DD, the first charge date (today or later).
    def with_init_date(init_date)
      set("init_date", assert_date(init_date))
    end

    # Key order: label, alias, model, frequency, limit_amt, tot_limit_amt, is_limit_amt_fixed, expiration_date,
    # init_date, methods, terms_url, terms_version. Raises InvalidArgumentError when the terms break the model rules.
    def to_h
      assert_model_rules

      data = { "label" => @label }
      data["alias"] = @optional["alias"] if @optional.key?("alias")
      data["model"] = @model
      OPTIONAL_ORDER.each { |key| data[key] = @optional[key] if @optional.key?(key) }
      data["terms_url"] = @terms_url
      data["terms_version"] = @optional["terms_version"] if @optional.key?("terms_version")
      data
    end

    private

    def set(key, value)
      @optional[key] = value
      self
    end

    def assert_model_rules
      if @model == MODEL_O
        forbidden = MODEL_O_FORBIDDEN.find { |key| @optional.key?(key) }
        raise InvalidArgumentError, "#{forbidden} is not allowed in recurring model O" unless forbidden.nil?
      end
      return unless @model == MODEL_A

      missing = MODEL_A_REQUIRED.find { |key| !@optional.key?(key) }
      raise InvalidArgumentError, "#{missing} is required in recurring model A" unless missing.nil?
      return unless @optional["is_limit_amt_fixed"] == false

      raise InvalidArgumentError, "Recurring model A requires a fixed amount (is_limit_amt_fixed = true)"
    end

    def assert_positive(value, field)
      raise InvalidArgumentError, "#{field} must be at least 1 (minor units)" unless value.is_a?(Integer) && value >= 1

      value
    end

    def assert_date(date)
      unless date.is_a?(String) && DATE.match?(date)
        raise InvalidArgumentError, %(Date "#{date}" must be in YYYY-MM-DD format)
      end

      date
    end
  end
end
