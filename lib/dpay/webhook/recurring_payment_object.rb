# frozen_string_literal: true

module DPay
  # The "recurring_payment" object of recurring_payment.* events, identified by the registration payment.
  class RecurringPaymentObject
    STATUS_PENDING = "pending"
    STATUS_ACTIVE = "active"
    STATUS_CANCELED = "canceled"
    STATUS_EXPIRED = "expired"
    STATUS_DECLINED = "declined"

    CANCELED_BY_MERCHANT = "merchant"
    CANCELED_BY_CUSTOMER = "customer"
    CANCELED_BY_DPAY = "dpay"

    # id: ID of the registration payment. alias: the alias you charge the recurring payment with. canceled_by:
    # merchant, customer or dpay when canceled; nil in other states. From "terms": model (A, M or O), frequency (e.g.
    # "1M"), limit_amount and total_limit_amount (minor units, no currency in this object), starts_on and expires_on
    # (YYYY-MM-DD).
    attr_reader :id, :alias, :status, :canceled_by, :payment_method, :payment_method_type, :model, :frequency,
                :limit_amount, :total_limit_amount, :starts_on, :expires_on, :created, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      fields = Internal::ObjectFields
      @raw = data
      @id = fields.string(data, "id") || ""
      @alias = fields.string(data, "alias")
      @status = fields.string(data, "status")
      @canceled_by = fields.string(data, "canceled_by")
      @payment_method = fields.hash_or_nil(data, "payment_method")
      @payment_method_type = fields.string(@payment_method || {}, "type")
      terms = fields.hash_or_nil(data, "terms") || {}
      @model = fields.string(terms, "model")
      @frequency = fields.string(terms, "frequency")
      @limit_amount = fields.integer_or_nil(terms, "limit_amount")
      @total_limit_amount = fields.integer_or_nil(terms, "total_limit_amount")
      @starts_on = fields.string(terms, "starts_on")
      @expires_on = fields.string(terms, "expires_on")
      @created = fields.string(data, "created")
      freeze
    end
  end
end
