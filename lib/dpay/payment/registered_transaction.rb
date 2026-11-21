# frozen_string_literal: true

module DPay
  # The transaction returned with a registration answered "Transaction paid" (additionalInfo.transaction) - the
  # payment was already paid (e.g. a repeated registration). Its statuses differ from Transaction#status:
  # pending, paid, captured, canceled.
  class RegisteredTransaction
    STATUS_PENDING = "pending"
    STATUS_PAID = "paid"
    STATUS_CAPTURED = "captured"
    STATUS_CANCELED = "canceled"

    # value: in the currency of the registered amount (the object carries none). pid: provider transaction
    # identifier, when known.
    attr_reader :payment_id, :status, :value, :email, :description, :name, :surname, :pid, :mtid, :creation_date,
                :payment_date, :raw

    # currency: currency of the registered amount.
    def self.from_api(data, currency = Currency::PLN)
      new(data, currency)
    end

    def initialize(data, currency = Currency::PLN)
      @raw = data
      @payment_id = string(data["payment_id"]) || ""
      @status = string(data["status"])
      @value = Money.try_from_api_number(data["value"], Currency.valid?(currency) ? currency : Currency::PLN)
      @email = string(data["email"])
      @description = string(data["description"])
      @name = string(data["name"])
      @surname = string(data["surname"])
      @pid = string(data["pid"])
      @mtid = string(data["mtid"])
      @creation_date = string(data["creation_date"])
      @payment_date = string(data["payment_date"])
      freeze
    end

    def paid?
      @status == STATUS_PAID || @status == STATUS_CAPTURED
    end

    private

    def string(value)
      value.is_a?(String) || value.is_a?(Integer) ? value.to_s : nil
    end
  end
end
