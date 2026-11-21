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
    # transaction_id: the transaction created before the error, when the API returned one ("transactionId", e.g. a
    # declined charge on a saved card or a declined payment) - use it to query the transaction.
    # card_error: card decline details (DPay::CardError) - "cardError" of a Payments API error, "error" of a declined
    # card operation.
    attr_reader :http_status, :error_code, :field_errors, :raw_body, :reason, :transaction_id, :card_error

    def initialize(message, http_status, error_code = nil, field_errors = {}, raw_body = "", reason = nil, # rubocop:disable Metrics/ParameterLists
                   transaction_id = nil, card_error = nil)
      super(message)
      @http_status = http_status
      @error_code = error_code
      @field_errors = field_errors
      @raw_body = raw_body
      @reason = reason
      @transaction_id = transaction_id
      @card_error = card_error
    end
  end

  class AuthenticationError < ApiError; end
  class InvalidRequestError < ApiError; end
  class AccessDeniedError < ApiError; end
  class NotFoundError < ApiError; end
  class ApiServerError < ApiError; end

  class RateLimitError < ApiError
    # reset: Unix time (seconds) when the limit resets - the X-RateLimit-Reset header.
    attr_reader :retry_after, :limit, :remaining, :reset

    def initialize(message, http_status, retry_after = nil, limit = nil, remaining = nil, raw_body = "", reset = nil)
      super(message, http_status, nil, {}, raw_body)
      @retry_after = retry_after
      @limit = limit
      @remaining = remaining
      @reset = reset
    end
  end

  class PaymentRejectedError < ApiError
    # error_description: the provider's description of the decline, when it sent one. transaction_id is inherited
    # from ApiError.
    attr_reader :error_description

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
      super(message, http_status, error_code, field_errors, raw_body, nil, transaction_id)
      @error_description = error_description
    end
  end

  # A card operation answered HTTP 200 with "success": false. message and error_code are the API "message"
  # (e.g. "DCC_OFFER_EXPIRED"); card_error carries the decline details ("error") when the decline has a known code.
  class CardPaymentError < ApiError
    def self.from_api(data)
      message = data["message"].is_a?(String) && !data["message"].empty? ? data["message"] : "Card payment rejected"
      card_error = data["error"].is_a?(Hash) ? CardError.from_api(data["error"]) : nil

      new(message, 200, message, {}, Internal::PHP.json_encode(data), nil, nil, card_error)
    end
  end
end
