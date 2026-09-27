# frozen_string_literal: true

module DPay
  module WebhookEventType
    PAYMENT_SUCCEEDED = "payment.succeeded"
    PAYMENT_FAILED = "payment.failed"
    PAYMENT_CAPTURED = "payment.captured"
    REFUND_SUCCEEDED = "refund.succeeded"
    REFUND_FAILED = "refund.failed"
    RECURRING_PAYMENT_ACTIVATED = "recurring_payment.activated"
    RECURRING_PAYMENT_CANCELED = "recurring_payment.canceled"
    RECURRING_PAYMENT_EXPIRED = "recurring_payment.expired"
    RECURRING_PAYMENT_DECLINED = "recurring_payment.declined"
    PAYOUT_PAID = "payout.paid"
    PAYOUT_FAILED = "payout.failed"
    WEBHOOK_TEST = "webhook.test"

    # Events allowed in the "webhook" object of a payment registration.
    PAYMENT_REGISTRATION = [
      PAYMENT_SUCCEEDED, PAYMENT_FAILED, PAYMENT_CAPTURED, REFUND_SUCCEEDED, REFUND_FAILED,
      RECURRING_PAYMENT_ACTIVATED, RECURRING_PAYMENT_CANCELED, RECURRING_PAYMENT_EXPIRED, RECURRING_PAYMENT_DECLINED
    ].freeze

    # Events a merchant endpoint can subscribe to and the Events API can filter on.
    MERCHANT = (PAYMENT_REGISTRATION + [PAYOUT_PAID, PAYOUT_FAILED]).freeze

    # Events allowed in the "webhook" object of a refund.
    REFUND = [REFUND_SUCCEEDED, REFUND_FAILED].freeze

    # Events allowed in the "webhook" object of a card capture.
    CAPTURE = [PAYMENT_CAPTURED].freeze

    def self.assert_allowed(events, allowed, context)
      events.each do |event|
        next if allowed.include?(event)

        raise InvalidArgumentError, %(Event "#{event}" is not allowed in the webhook object of #{context})
      end

      nil
    end
  end
end
