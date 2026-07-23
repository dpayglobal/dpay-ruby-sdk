# frozen_string_literal: true

module DPay
  class RegisteredPayment
    REDIRECT = %r{\Ahttps?://}
    PAID = "Transaction paid"
    INTERNAL_PROCESSING = "Internal processing"

    attr_reader :transaction_id, :message, :ipksef, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @transaction_id = Internal::Coerce.string(data["transactionId"]) || ""
      @message = Internal::Coerce.string(data["msg"]) || ""
      @ipksef = data["ipksef"].is_a?(String) ? data["ipksef"] : nil
      freeze
    end

    def redirect_url
      REDIRECT.match?(@message) ? @message : nil
    end

    def paid?
      @message == PAID
    end

    def internal_processing?
      @message == INTERNAL_PROCESSING
    end

    def card_recurring_alias
      additional = @raw["additionalInfo"]
      return nil unless additional.is_a?(Hash) && additional["card_recurring_alias"].is_a?(String)

      additional["card_recurring_alias"]
    end
  end
end
