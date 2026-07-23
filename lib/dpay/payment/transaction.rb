# frozen_string_literal: true

module DPay
  class Transaction
    attr_reader :id, :value, :status, :payment_method, :creation_date, :payment_date,
                :refunded_amount, :available_refund_amount, :gateway_id, :payer, :refunds, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      tx = data["transaction"].is_a?(Hash) ? data["transaction"] : {}

      @id = Internal::Coerce.string(tx["id"]) || ""
      @value = Internal::Coerce.money(tx["value"])
      @status = Internal::Coerce.string(tx["status"]) || ""
      @payment_method = Internal::Coerce.string(tx["payment_method"])
      @creation_date = Internal::Coerce.string(tx["creation_date"])
      @payment_date = tx["payment_date"].is_a?(String) ? tx["payment_date"] : nil
      @settled = Internal::Coerce.boolean(tx["settled"])
      @refunded = Internal::Coerce.boolean(tx["refunded"])
      @refunded_amount = Internal::Coerce.money(tx["refunded_amount"])
      @available_refund_amount = Internal::Coerce.money(tx["available_refund_amount"])
      @fully_refunded = Internal::Coerce.boolean(tx["fully_refunded"])
      @direct = Internal::Coerce.boolean(tx["direct"])
      @gateway_id = tx["gateway_id"].is_a?(String) ? tx["gateway_id"] : nil
      @payer = data["payer"].is_a?(Hash) ? data["payer"] : {}
      @refunds = Internal::Coerce.list(data["refunds"]).map { |refund| TransactionRefund.from_api(refund) }
      freeze
    end

    def paid?
      @status == TransactionStatus::PAID || @status == TransactionStatus::CAPTURED
    end

    def settled?
      @settled
    end

    def refunded?
      @refunded
    end

    def fully_refunded?
      @fully_refunded
    end

    def direct?
      @direct
    end
  end
end
