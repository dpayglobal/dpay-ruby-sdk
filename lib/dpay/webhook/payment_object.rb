# frozen_string_literal: true

module DPay
  # The "payment" object of payment.* events. Amounts in minor units of #currency, times in UTC (ISO 8601).
  class PaymentObject
    STATUS_PENDING = "pending"
    STATUS_PROCESSING = "processing"
    STATUS_SUCCEEDED = "succeeded"
    STATUS_CAPTURED = "captured"
    STATUS_FAILED = "failed"
    STATUS_REVERSED = "reversed"
    STATUS_CHARGED_BACK = "charged_back"

    SEQUENCE_FIRST = "first"
    SEQUENCE_SUBSEQUENT = "subsequent"

    # id: payment ID - the transactionId of the registration. amount_captured: total captured from a card
    # pre-authorisation. paid_at: nil until the payment is paid. payment_method: {type, <type> => details}, e.g.
    # {"type" => "blik", "blik" => {"flow" => "code"}}; nil while unknown. payment_method_type: blik, card,
    # bank_transfer, twisto, multibanco, blik_pay_later, mb_way, paypal, paypo, paysafecard. failure: decline reason in
    # payment.failed. recurring_alias, recurring_registration (ID of the payment that registered the recurring
    # payment), recurring_sequence ("first" or "subsequent"): from "recurring". merchant_reference: your reference
    # from the registration; provider_reference: transaction ID at the provider, if available.
    attr_reader :id, :status, :currency, :amount, :amount_refunded, :amount_captured, :description, :created,
                :paid_at, :payment_method, :payment_method_type, :failure, :recurring_alias,
                :recurring_registration, :recurring_sequence, :merchant_reference, :provider_reference, :custom, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      fields = Internal::ObjectFields
      @raw = data
      @id = fields.string(data, "id") || ""
      @status = fields.string(data, "status")
      @currency = fields.currency(data)
      @amount = fields.money(data, "amount", @currency)
      @amount_refunded = fields.money(data, "amount_refunded", @currency)
      @amount_captured = fields.money(data, "amount_captured", @currency)
      @description = fields.string(data, "description")
      @created = fields.string(data, "created")
      @paid_at = fields.string(data, "paid_at")
      @payment_method = fields.hash_or_nil(data, "payment_method")
      @payment_method_type = fields.string(@payment_method || {}, "type")
      failure = fields.hash_or_nil(data, "failure")
      @failure = failure.nil? ? nil : Failure.from_api(failure)
      recurring = fields.hash_or_nil(data, "recurring")
      @recurring = !recurring.nil?
      @recurring_alias = fields.string(recurring || {}, "alias")
      @recurring_registration = fields.string(recurring || {}, "registration")
      @recurring_sequence = fields.string(recurring || {}, "sequence")
      references = fields.hash_or_nil(data, "references") || {}
      @merchant_reference = fields.string(references, "merchant")
      @provider_reference = fields.string(references, "provider")
      @custom = fields.string(data, "custom")
      freeze
    end

    def recurring?
      @recurring
    end
  end
end
