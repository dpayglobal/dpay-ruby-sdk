# frozen_string_literal: true

module DPay
  # Terms of a registered recurring payment, as returned by the status endpoint. Amounts in minor units (grosz).
  class RecurringRegistrationInfo
    DIGITS = /\A\d+\z/

    # transaction_id: transactionId of the registering payment. registered_at: ISO 8601 with offset.
    attr_reader :transaction_id, :label, :model, :frequency, :limit_amt, :tot_limit_amt, :limit_amt_fixed,
                :init_date, :terms_url, :terms_version, :registered_at, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @transaction_id = string(data["transaction_id"])
      @label = string(data["label"])
      @model = string(data["model"])
      @frequency = string(data["frequency"])
      @limit_amt = integer(data["limit_amt"])
      @tot_limit_amt = integer(data["tot_limit_amt"])
      fixed = data["is_limit_amt_fixed"]
      @limit_amt_fixed = [true, false].include?(fixed) ? fixed : nil
      @init_date = string(data["init_date"])
      @terms_url = string(data["terms_url"])
      @terms_version = string(data["terms_version"])
      @registered_at = string(data["registered_at"])
      freeze
    end

    private

    def string(value)
      value.is_a?(String) ? value : nil
    end

    def integer(value)
      return value if value.is_a?(Integer)

      value.is_a?(String) && DIGITS.match?(value) ? value.to_i : nil
    end
  end
end
