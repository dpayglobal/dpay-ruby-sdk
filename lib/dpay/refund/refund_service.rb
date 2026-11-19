# frozen_string_literal: true

module DPay
  class RefundService
    # Request header with your own refund identifier; it sets the refund transfer title.
    MESSAGE_ID_HEADER = "DigitalPayments-PSP-Message-ID"
    MESSAGE_ID = /\A[\x20-\x7E]+\z/
    # @deprecated since 0.3.0 every 4xx answer carrying the "refund" key (except 401 "Unauthorized request") is an
    # availability outcome; this list of the 0.2.0 statuses is no longer used.
    AVAILABILITY_STATUSES = [200, 400, 402, 406, 409, 410, 411].freeze

    def initialize(api)
      @api = api
    end

    # Orders a refund (partial with an amount, the rest of the payment without). A successful response means the
    # refund was accepted - its outcome comes as a "refund.succeeded" / "refund.failed" event. The optional webhook
    # target receives the events of this refund and is part of the checksum.
    #
    # message_id: your own refund identifier, sent in the DigitalPayments-PSP-Message-ID header (not part of the
    # checksum): the refund transfer title becomes "dpay.pl zwrot <message_id>" and Refund#message returns it.
    # Printable ASCII; the API keeps the first 24 characters.
    def create(transaction_id, amount = nil, reason = nil, webhook = nil, message_id = nil)
      webhook&.assert_events_allowed(WebhookEventType::REFUND, "a refund")
      # @type var headers: Hash[String, String]
      headers = {}
      unless message_id.nil?
        unless message_id.is_a?(String) && MESSAGE_ID.match?(message_id) && !Internal::PHP.trim(message_id).empty?
          raise InvalidArgumentError, "Refund message ID must be non-empty printable ASCII"
        end

        headers[MESSAGE_ID_HEADER] = message_id
      end
      body = signed_body(transaction_id, amount, reason, webhook)

      Refund.from_api(@api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/refund", body, headers))
    end

    # Checks whether the refund is possible. Every answer that carries the "refund" key - HTTP 200 and the business
    # refusals 400, 402, 404 (transaction does not exist), 406, 409, 410, 411, 423 and a business 401 - is returned
    # as RefundAvailability (http_status tells the reason apart). An invalid checksum (401 "Unauthorized request"),
    # validation errors (422), rate limits and server errors raise.
    def check_availability(transaction_id, amount = nil, reason = nil)
      body = signed_body(transaction_id, amount, reason)
      response = @api.send_raw("POST", Internal::BaseUrls::PANEL, "/api/v1/pbl/check-refund-availability", body)
      data = response.decode_json

      if data.is_a?(Hash) && data.key?("refund") && availability_outcome?(response.status, data)
        return RefundAvailability.from_api(data, response.status)
      end

      raise @api.map_error(response)
    end

    private

    def availability_outcome?(status, data)
      return data["message"] != "Unauthorized request" if status == 401

      status == 200 || (400..499).cover?(status)
    end

    def signed_body(transaction_id, amount, reason, webhook = nil)
      # @type var body: Hash[String, untyped]
      body = { "service" => @api.service, "transaction_id" => transaction_id }
      body["value"] = amount.to_decimal unless amount.nil?
      body["reason"] = reason unless reason.nil?
      body["webhook"] = webhook.to_h unless webhook.nil?
      body["checksum"] = @api.checksum.ordered_body(body)

      body
    end
  end
end
