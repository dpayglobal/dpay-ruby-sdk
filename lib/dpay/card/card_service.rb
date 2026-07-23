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

    def capture(transaction_id, amount)
      post(transaction_id, "/capture", { "amount" => amount.to_decimal.to_f })
    end

    def cancel(transaction_id, amount = nil)
      post(transaction_id, "/cancellation", amount.nil? ? {} : { "amount" => amount.to_decimal.to_f })
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
