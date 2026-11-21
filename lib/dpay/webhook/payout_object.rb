# frozen_string_literal: true

module DPay
  # The "payout" object of payout.* events (account events, without a service).
  class PayoutObject
    STATUS_PENDING = "pending"
    STATUS_PAID = "paid"
    STATUS_FAILED = "failed"

    # id: payout ID - the withdraw_id of payouts.details. amount: net payout amount. bank_account_last4: last 4 digits
    # of the destination account. failure: in payout.failed "payout_failed", Failure#provider_code tells what happened
    # to the funds.
    attr_reader :id, :status, :currency, :amount, :fee, :bank_account_last4, :created, :paid_at, :failure, :raw

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
      @fee = fields.money(data, "fee", @currency)
      @bank_account_last4 = fields.string(fields.hash_or_nil(data, "bank_account") || {}, "last4")
      @created = fields.string(data, "created")
      @paid_at = fields.string(data, "paid_at")
      failure = fields.hash_or_nil(data, "failure")
      @failure = failure.nil? ? nil : Failure.from_api(failure)
      freeze
    end
  end
end
