# frozen_string_literal: true

module DPay
  class PayoutService
    def initialize(api)
      @api = api
    end

    def details(withdraw_id, timestamp = nil)
      body = { "service" => @api.service }
      body["timestamp"] = timestamp unless timestamp.nil?
      body["withdraw_id"] = withdraw_id
      body["checksum"] = @api.checksum.ordered_body(body.values)

      data = @api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/withdraws/details", body)
      unless data.is_a?(Hash) && Internal::Coerce.integer(data["id"]).positive?
        raise ApiServerError.new("API response carries no payout details", 200, nil, {}, Internal::PHP.json_encode(data))
      end

      PayoutDetails.from_api(data)
    end
  end
end
