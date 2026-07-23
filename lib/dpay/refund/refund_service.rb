# frozen_string_literal: true

module DPay
  class RefundService
    AVAILABILITY_STATUSES = [200, 400, 402, 406, 409, 410, 411].freeze

    def initialize(api)
      @api = api
    end

    def create(transaction_id, amount = nil, reason = nil)
      body = signed_body(transaction_id, amount, reason)

      Refund.from_api(@api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/refund", body))
    end

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
      return true if AVAILABILITY_STATUSES.include?(status)

      status == 401 && data["message"] != "Unauthorized request"
    end

    def signed_body(transaction_id, amount, reason)
      body = { "service" => @api.service, "transaction_id" => transaction_id }
      body["value"] = amount.to_decimal unless amount.nil?
      body["reason"] = reason unless reason.nil?
      body["checksum"] = @api.checksum.ordered_body(body.values)

      body
    end
  end
end
