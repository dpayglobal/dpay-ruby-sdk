# frozen_string_literal: true

module DPay
  # Who can fix a decline (failure.category).
  module FailureCategory
    # The customer (funds, limits, code, bank app) - they can pay again.
    CUSTOMER = "customer"
    # Your request or configuration.
    MERCHANT = "merchant"
    # Security checks - do not retry automatically.
    RISK = "risk"
    # dpay or the provider - temporary errors.
    SYSTEM = "system"

    ALL = [CUSTOMER, MERCHANT, RISK, SYSTEM].freeze
  end
end
