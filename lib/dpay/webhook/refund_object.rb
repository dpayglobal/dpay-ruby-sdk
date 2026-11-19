# frozen_string_literal: true

module DPay
  # The "refund" object of refund.* events.
  class RefundObject
    STATUS_SUCCEEDED = "succeeded"
    STATUS_FAILED = "failed"

    # id: refund ID ("ZWROT-..."); nil for a refund rejected before it was created. payment: ID of the refunded
    # payment. failure: rejection reason in refund.failed, e.g. "refund_window_expired".
    attr_reader :id, :payment, :status, :currency, :amount, :created, :succeeded_at, :failure, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      fields = Internal::ObjectFields
      @raw = data
      @id = fields.string(data, "id")
      @payment = fields.string(data, "payment")
      @status = fields.string(data, "status")
      @currency = fields.currency(data)
      @amount = fields.money(data, "amount", @currency)
      @created = fields.string(data, "created")
      @succeeded_at = fields.string(data, "succeeded_at")
      failure = fields.hash_or_nil(data, "failure")
      @failure = failure.nil? ? nil : Failure.from_api(failure)
      freeze
    end
  end
end
