# frozen_string_literal: true

module DPay
  # Webhook event envelope: {id, type, api_version, created, livemode, service, [merchant_ref], data: {object}}.
  # data.object is available as a Hash (#object) and as a typed model of its kind: #payment, #refund,
  # #recurring_payment, #payout - amounts in minor units.
  class WebhookEvent
    # created: event time in UTC ("YYYY-MM-DDTHH:MM:SSZ") - not the delivery time, do not use it against replays.
    # service: nil for account events (payouts) and test events. merchant_ref: only in events sent to a dpay Connect
    # partner. object_type: "payment", "refund", "recurring_payment", "payout" or "webhook_endpoint".
    attr_reader :id, :type, :api_version, :created, :service, :merchant_ref, :object, :object_type, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @id = string(data["id"]) || ""
      @type = string(data["type"]) || ""
      @api_version = string(data["api_version"])
      @created = string(data["created"])
      @livemode = data["livemode"] != false
      @service = string(data["service"])
      @merchant_ref = string(data["merchant_ref"])
      envelope = data["data"]
      object = envelope.is_a?(Hash) ? envelope["object"] : nil
      @object = object.is_a?(Hash) ? object : {}
      @object_type = string(@object["object"])
      freeze
    end

    def livemode?
      @livemode
    end

    # The "payment" object of payment.* events (DPay::PaymentObject); nil for other objects.
    def payment
      @object_type == "payment" ? PaymentObject.from_api(@object) : nil
    end

    # The "refund" object of refund.* events (DPay::RefundObject); nil for other objects.
    def refund
      @object_type == "refund" ? RefundObject.from_api(@object) : nil
    end

    # The "recurring_payment" object of recurring_payment.* events (DPay::RecurringPaymentObject); nil for other
    # objects.
    def recurring_payment
      @object_type == "recurring_payment" ? RecurringPaymentObject.from_api(@object) : nil
    end

    # The "payout" object of payout.* events (DPay::PayoutObject); nil for other objects.
    def payout
      @object_type == "payout" ? PayoutObject.from_api(@object) : nil
    end

    private

    def string(value)
      value.is_a?(String) ? value : nil
    end
  end
end
