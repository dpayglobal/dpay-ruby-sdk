# frozen_string_literal: true

module DPay
  class CardService
    def initialize(api)
      @api = api
    end

    def public_key
      @api.get_text(Internal::BaseUrls::API_PAYMENTS, "/api/v1_0/cards/public-key").strip
    end

    def pay_otp(transaction_id, request)
      post(transaction_id, "/pay/card-otp", request.to_body)
    end

    def pre_auth(transaction_id, request)
      post(transaction_id, "/pay/card-pre-auth", request.to_body)
    end

    # Captures a pre-authorised amount (partial captures allowed up to the authorisation). Signed with
    # sha256(capture|service|transaction_id|amount|hash). Optional webhook target for "payment.captured".
    def capture(transaction_id, amount, webhook = nil)
      # @type var body: Hash[String, untyped]
      body = { "service" => @api.service, "amount" => amount.to_decimal.to_f }
      unless webhook.nil?
        webhook.assert_events_allowed(WebhookEventType::CAPTURE, "a card capture")
        body["webhook"] = webhook.to_h
      end
      body["checksum"] = @api.checksum.operation("capture", @api.service, transaction_id, amount.to_decimal)

      post(transaction_id, "/capture", body)
    end

    # Cancels the pre-authorisation, the whole uncaptured remainder without an amount. Signed with
    # sha256(cancellation|service|transaction_id|amount|hash) - empty amount segment without an amount.
    def cancel(transaction_id, amount = nil)
      body = { "service" => @api.service }
      body["amount"] = amount.to_decimal.to_f unless amount.nil?
      body["checksum"] = @api.checksum.operation("cancellation", @api.service, transaction_id, amount&.to_decimal)

      post(transaction_id, "/cancellation", body)
    end

    def google_pay(transaction_id, request)
      post(transaction_id, "/pay/google-pay", request.to_body)
    end

    def apple_pay(transaction_id, request)
      post(transaction_id, "/pay/apple-pay", request.to_body)
    end

    private

    def post(transaction_id, suffix, body)
      path = "/api/v1_0/cards/payment/#{Internal::PHP.raw_url_encode(transaction_id)}#{suffix}"
      data = @api.post_json(Internal::BaseUrls::API_PAYMENTS, path, body)
      raise CardPaymentError.from_api(data) unless data["success"] == true

      CardPaymentResult.from_api(data)
    end
  end
end
