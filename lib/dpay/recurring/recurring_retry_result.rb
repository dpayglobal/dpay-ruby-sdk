# frozen_string_literal: true

module DPay
  # Result of retrying a declined recurring charge. "pending" - the retry went to the bank, the outcome comes like for
  # a charge (webhook, IPN, status); "failed" - the bank declined it at once (error code in #error_code).
  class RecurringRetryResult
    STATUS_PENDING = "pending"
    STATUS_FAILED = "failed"
    STATUS_SUCCESS = "success"

    # count: which retry this was (1-3).
    attr_reader :transaction_id, :status, :count, :error_code, :error_description, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      details = data["retry"].is_a?(Hash) ? data["retry"] : {}
      @transaction_id = Internal::Coerce.string(data["transactionId"]) || ""
      @status = string(details["status"])
      @count = details["count"].is_a?(Integer) ? details["count"] : nil
      @error_code = string(details["error"])
      @error_description = string(details["error_description"])
      freeze
    end

    def pending?
      @status == STATUS_PENDING
    end

    def failed?
      @status == STATUS_FAILED
    end

    private

    def string(value)
      value.is_a?(String) ? value : nil
    end
  end
end
