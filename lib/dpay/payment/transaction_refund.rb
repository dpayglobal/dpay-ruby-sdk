# frozen_string_literal: true

module DPay
  class TransactionRefund
    attr_reader :payment_id, :value, :status, :creation_date, :payment_date, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @payment_id = Internal::Coerce.string(data["payment_id"]) || ""
      @value = Internal::Coerce.money(data["value"])
      @status = Internal::Coerce.string(data["status"]) || TransactionStatus::PAID
      @creation_date = Internal::Coerce.string(data["creation_date"])
      @payment_date = Internal::Coerce.string(data["payment_date"])
      freeze
    end
  end
end
