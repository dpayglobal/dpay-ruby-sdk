# frozen_string_literal: true

module DPay
  class InvoiceDetails
    DATE = /\A\d{4}-\d{2}-\d{2}\z/

    def self.create
      new
    end

    def initialize
      @data = {}
    end

    def with_payer_nip(payer_nip)
      @data["payer_nip"] = payer_nip
      self
    end

    def with_payer_name(payer_name)
      @data["payer_name"] = payer_name
      self
    end

    def with_invoice_number(invoice_number)
      @data["invoice_number"] = invoice_number
      self
    end

    def with_payment_due_date(payment_due_date)
      unless payment_due_date.is_a?(String) && DATE.match?(payment_due_date)
        raise InvalidArgumentError, "Payment due date must be in YYYY-MM-DD format"
      end

      @data["payment_due_date"] = payment_due_date
      self
    end

    def with_vat_amount(vat_amount)
      @data["vat_amount"] = vat_amount.minor
      self
    end

    def to_h
      @data.dup
    end
  end
end
