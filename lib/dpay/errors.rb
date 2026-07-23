# frozen_string_literal: true

module DPay
  module Error; end

  class InvalidArgumentError < ArgumentError
    include Error
  end

  class TransportError < StandardError
    include Error
  end

  class SignatureVerificationError < StandardError
    include Error
  end

  class CardEncryptionError < StandardError
    include Error
  end

  class ApiError < StandardError
    include Error

    attr_reader :http_status, :error_code, :field_errors, :raw_body

    def initialize(message, http_status, error_code = nil, field_errors = {}, raw_body = "")
      super(message)
      @http_status = http_status
      @error_code = error_code
      @field_errors = field_errors
      @raw_body = raw_body
    end
  end

  class AuthenticationError < ApiError; end
  class InvalidRequestError < ApiError; end
  class AccessDeniedError < ApiError; end
  class NotFoundError < ApiError; end
  class ApiServerError < ApiError; end

  class RateLimitError < ApiError
    attr_reader :retry_after, :limit, :remaining

    def initialize(message, http_status, retry_after = nil, limit = nil, remaining = nil, raw_body = "")
      super(message, http_status, nil, {}, raw_body)
      @retry_after = retry_after
      @limit = limit
      @remaining = remaining
    end
  end

  class PaymentRejectedError < ApiError
    attr_reader :transaction_id

    def self.from_api(data)
      message = %w[message msg].filter_map { |key| data[key] if data[key].is_a?(String) }.first || "Payment rejected"
      error_code = data["errorcode"].is_a?(String) ? data["errorcode"] : nil
      transaction_id = data["transactionId"].nil? ? nil : Internal::PHP.strval(data["transactionId"])

      new(message, 200, error_code, {}, Internal::PHP.json_encode(data), transaction_id)
    end

    def initialize(message, http_status, error_code = nil, field_errors = {}, raw_body = "", transaction_id = nil)
      super(message, http_status, error_code, field_errors, raw_body)
      @transaction_id = transaction_id
    end
  end

  class CardPaymentError < ApiError
    def self.from_api(data)
      message = data["message"].is_a?(String) && !data["message"].empty? ? data["message"] : "Card payment rejected"

      new(message, 200, message, {}, Internal::PHP.json_encode(data))
    end
  end
end
