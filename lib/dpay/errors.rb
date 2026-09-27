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

    # reason: detail next to the error code, e.g. "https_required" for WEBHOOK_URL_INVALID.
    attr_reader :http_status, :error_code, :field_errors, :raw_body, :reason

    def initialize(message, http_status, error_code = nil, field_errors = {}, raw_body = "", reason = nil)
      super(message)
      @http_status = http_status
      @error_code = error_code
      @field_errors = field_errors
      @raw_body = raw_body
      @reason = reason
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
    # error_description: the provider's description of the decline, when it sent one.
    attr_reader :transaction_id, :error_description

    def self.from_api(data)
      message = %w[message msg].filter_map { |key| data[key] if data[key].is_a?(String) }.first || "Payment rejected"
      additional = data["additionalInfo"].is_a?(Hash) ? data["additionalInfo"] : {}
      error_code = [data["errorcode"], additional["error"]].find { |code| code.is_a?(String) }
      transaction_id = data["transactionId"].nil? ? nil : Internal::PHP.strval(data["transactionId"])
      description = additional["error_description"].is_a?(String) ? additional["error_description"] : nil

      new(message, 200, error_code, {}, Internal::PHP.json_encode(data), transaction_id, description)
    end

    def initialize(message, http_status, error_code = nil, field_errors = {}, raw_body = "", transaction_id = nil,
                   error_description = nil)
      super(message, http_status, error_code, field_errors, raw_body)
      @transaction_id = transaction_id
      @error_description = error_description
    end
  end

  class CardPaymentError < ApiError
    def self.from_api(data)
      message = data["message"].is_a?(String) && !data["message"].empty? ? data["message"] : "Card payment rejected"

      new(message, 200, message, {}, Internal::PHP.json_encode(data))
    end
  end
end
