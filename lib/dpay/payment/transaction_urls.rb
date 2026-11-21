# frozen_string_literal: true

module DPay
  # Return and IPN addresses stored with a transaction (transaction.urls of payments.details).
  class TransactionUrls
    # ipn: nil when the payment was registered without an IPN address.
    attr_reader :success, :fail, :ipn

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @success = string(data["success"])
      @fail = string(data["fail"])
      @ipn = string(data["ipn"])
      freeze
    end

    private

    def string(value)
      value.is_a?(String) && !value.empty? ? value : nil
    end
  end
end
