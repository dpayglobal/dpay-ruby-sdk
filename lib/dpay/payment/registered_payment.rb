# frozen_string_literal: true

module DPay
  class RegisteredPayment
    REDIRECT = %r{\Ahttps?://}
    PAID = "Transaction paid"
    INTERNAL_PROCESSING = "Internal processing"

    attr_reader :transaction_id, :message, :ipksef, :raw

    # currency: currency of the registered amount (for #paid_transaction).
    def self.from_api(data, currency = Currency::PLN)
      new(data, currency)
    end

    def initialize(data, currency = Currency::PLN)
      @raw = data
      @currency = Currency.valid?(currency) ? currency : Currency::PLN
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

    # Alias of the recurring payment registered with this payment (with_recurring_registration).
    def recurring_alias
      value = recurring_registration["alias"]
      value.is_a?(String) ? value : nil
    end

    def recurring_methods
      names = recurring_registration["methods"]
      names.is_a?(Array) ? names.grep(String) : []
    end

    # Multibanco reference to show the payer (registration with the Multibanco channel).
    def multibanco
      multibanco = @raw["multibanco"]
      multibanco.is_a?(Hash) ? MultibancoReference.from_api(multibanco) : nil
    end

    # The already paid transaction of a "Transaction paid" answer (additionalInfo.transaction).
    def paid_transaction
      additional = @raw["additionalInfo"]
      transaction = additional.is_a?(Hash) ? additional["transaction"] : nil
      transaction.is_a?(Hash) ? RegisteredTransaction.from_api(transaction, @currency) : nil
    end

    private

    def recurring_registration
      additional = @raw["additionalInfo"]
      registration = additional.is_a?(Hash) ? additional["recurring_registration"] : nil
      registration.is_a?(Hash) ? registration : {}
    end
  end
end
