# frozen_string_literal: true

module DPay
  # Per-request webhook address (the "webhook" object of a payment registration, refund or card capture). Events of
  # this payment go to this URL, signed with the service's webhook secret, on top of the endpoints set in the panel.
  class WebhookTarget
    HTTPS_URL = %r{\Ahttps://[^\s]+\z}i
    URL_MAX = 500

    attr_reader :url, :events

    # events: empty = every event the request allows.
    def self.create(url, events = [])
      new(url, events)
    end

    def initialize(url, events = [])
      raise InvalidArgumentError, "Webhook URL must be at most 500 characters" if url.to_s.bytesize > URL_MAX
      unless url.is_a?(String) && HTTPS_URL.match?(url)
        raise InvalidArgumentError, %(Webhook URL "#{url}" must be a valid https:// URL)
      end
      unless events.is_a?(Array) && events.uniq.size == events.size
        raise InvalidArgumentError, "Webhook events must be distinct"
      end

      WebhookEventType.assert_allowed(events, WebhookEventType::MERCHANT, "a request")

      @url = url
      @events = events.dup.freeze
      freeze
    end

    def assert_events_allowed(allowed, context)
      WebhookEventType.assert_allowed(@events, allowed, context)
    end

    # "url" first, then "events" - the refund checksum hashes the values in this order.
    def to_h
      # @type var data: Hash[String, untyped]
      data = { "url" => @url }
      data["events"] = @events.dup unless @events.empty?
      data
    end
  end
end
