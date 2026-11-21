# frozen_string_literal: true

module DPay
  # Decline reason of a webhook object ("failure"): payment.failed, refund.failed, payout.failed.
  class Failure
    # code: dpay decline code (DeclineCode), e.g. "insufficient_funds"; GENERIC_DECLINE when missing.
    # message: English description of the code. category: customer, merchant, risk or system (FailureCategory).
    # provider_code: original provider code (e.g. a BLIK code), or for payout_failed what happened to the funds.
    attr_reader :code, :message, :category, :provider_code, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      code = data["code"]
      @code = code.is_a?(String) && !code.empty? ? code : DeclineCode::GENERIC_DECLINE
      @message = data["message"].is_a?(String) ? data["message"] : nil
      @category = data["category"].is_a?(String) ? data["category"] : nil
      @retryable = data["retryable"] == true
      @provider_code = Internal::ObjectFields.string(data, "provider_code")
      freeze
    end

    # Whether the same payment may succeed when tried again (e.g. after topping up the account).
    def retryable?
      @retryable
    end
  end
end
