# frozen_string_literal: true

module DPay
  # Why recurring.retry was refused (HTTP 400, nothing sent to BLIK): the DPay::InvalidRequestError field error
  # "retry" - field_errors["retry"][0]. With DECLINE_NOT_RETRYABLE the decline code is in
  # field_errors["decline_reason"][0].
  module RetryRefusal
    PAYMENT_NOT_DECLINED = "PAYMENT_NOT_DECLINED"
    DECLINE_NOT_RETRYABLE = "DECLINE_NOT_RETRYABLE"
    RETRY_LIMIT_REACHED = "RETRY_LIMIT_REACHED"
    RETRY_WINDOW_EXPIRED = "RETRY_WINDOW_EXPIRED"
    ALIAS_NOT_AVAILABLE = "ALIAS_NOT_AVAILABLE"
    RECURRING_NOT_ENABLED = "RECURRING_NOT_ENABLED"
    PAYMENT_NOT_FOUND = "PAYMENT_NOT_FOUND"
    SERVICE_UNAVAILABLE = "Service unavailable"

    ALL = [
      PAYMENT_NOT_DECLINED, DECLINE_NOT_RETRYABLE, RETRY_LIMIT_REACHED, RETRY_WINDOW_EXPIRED, ALIAS_NOT_AVAILABLE,
      RECURRING_NOT_ENABLED, PAYMENT_NOT_FOUND, SERVICE_UNAVAILABLE
    ].freeze
  end
end
