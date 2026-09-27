# frozen_string_literal: true

module DPay
  class PaymentService
    def initialize(api)
      @api = api
    end

    def register(request)
      body = request.to_body(@api.service)
      fields = [body["value"], body["url_success"], body["url_fail"], body["url_ipn"]]
      # A recurring charge binds the checksum to the customer's alias
      fields << body["recurring_alias"] unless body["recurring_alias"].nil?
      body["checksum"] = @api.checksum.secret_second(@api.service, fields)

      data = @api.post_json(Internal::BaseUrls::API_PAYMENTS, "/api/v1_0/payments/register", body)
      raise PaymentRejectedError.from_api(data) if rejected?(data)

      RegisteredPayment.from_api(data)
    end

    def details(transaction_id)
      body = { "service" => @api.service, "transaction_id" => transaction_id }
      body["checksum"] = @api.checksum.ordered_body(body.values)

      Transaction.from_api(@api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/details", body))
    end

    private

    def rejected?(data)
      data["error"] == true || data["status"] == false
    end
  end
end
