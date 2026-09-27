# frozen_string_literal: true

module DPay
  # Webhook event envelope: {id, type, api_version, created, livemode, service, [merchant_ref], data: {object}}.
  # data.object stays a Hash - payment, refund, recurring_payment or payout, amounts in minor units.
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

    private

    def string(value)
      value.is_a?(String) ? value : nil
    end
  end
end
