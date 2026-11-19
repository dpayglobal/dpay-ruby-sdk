# frozen_string_literal: true

module DPay
  # dpay decline codes (failure.code of webhook objects). React to a decline by Failure#category and
  # Failure#retryable?; new codes may appear - treat an unknown code like GENERIC_DECLINE.
  module DeclineCode
    INSUFFICIENT_FUNDS = "insufficient_funds"
    LIMIT_EXCEEDED = "limit_exceeded"
    CUSTOMER_DECLINED = "customer_declined"
    CUSTOMER_TIMEOUT = "customer_timeout"
    INVALID_CODE = "invalid_code"
    EXPIRED = "expired"
    APP_UPDATE_REQUIRED = "app_update_required"
    ISSUER_DECLINED = "issuer_declined"
    CARD_INVALID = "card_invalid"
    AUTHENTICATION_REQUIRED = "authentication_required"
    ALIAS_INVALID = "alias_invalid"
    UNSUPPORTED_BY_BANK = "unsupported_by_bank"
    GENERIC_DECLINE = "generic_decline"
    SECURITY_DECLINED = "security_declined"
    BLOCKED = "blocked"
    RECURRING_CONDITIONS_NOT_MET = "recurring_conditions_not_met"
    INVALID_REQUEST = "invalid_request"
    REFUND_WINDOW_EXPIRED = "refund_window_expired"
    REFUND_AMOUNT_EXCEEDED = "refund_amount_exceeded"
    PAYOUT_FAILED = "payout_failed"
    REFUND_FAILED = "refund_failed"
    PROCESSING_ERROR = "processing_error"

    ALL = [
      INSUFFICIENT_FUNDS, LIMIT_EXCEEDED, CUSTOMER_DECLINED, CUSTOMER_TIMEOUT, INVALID_CODE, EXPIRED,
      APP_UPDATE_REQUIRED, ISSUER_DECLINED, CARD_INVALID, AUTHENTICATION_REQUIRED, ALIAS_INVALID, UNSUPPORTED_BY_BANK,
      GENERIC_DECLINE, SECURITY_DECLINED, BLOCKED, RECURRING_CONDITIONS_NOT_MET, INVALID_REQUEST, REFUND_WINDOW_EXPIRED,
      REFUND_AMOUNT_EXCEEDED, PAYOUT_FAILED, REFUND_FAILED, PROCESSING_ERROR
    ].freeze
  end
end
