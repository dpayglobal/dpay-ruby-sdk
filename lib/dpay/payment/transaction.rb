# frozen_string_literal: true

module DPay
  class Transaction
    INTEGER = /\A-?\d+\z/

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

    # dpay commission rate in percent as sent (e.g. "1.50").
    def rate
      rate = transaction_data["rate"]
      rate.is_a?(String) || rate.is_a?(Integer) || rate.is_a?(Float) ? Internal::PHP.strval(rate) : nil
    end

    # Minimal commission as sent by the API (minimal_fee, e.g. 20 = 0.20 PLN).
    def minimal_fee
      integer_field("minimal_fee")
    end

    # Added fixed commission as sent by the API (permanent_fee, cards only).
    def permanent_fee
      integer_field("permanent_fee")
    end

    # Return and IPN addresses of the registration (DPay::TransactionUrls).
    def urls
      urls = transaction_data["urls"]
      urls.is_a?(Hash) ? TransactionUrls.from_api(urls) : nil
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

    private

    def transaction_data
      @raw["transaction"].is_a?(Hash) ? @raw["transaction"] : {}
    end

    def integer_field(key)
      value = transaction_data[key]
      return value if value.is_a?(Integer)

      value.is_a?(String) && INTEGER.match?(value) ? value.to_i : nil
    end
  end
end
