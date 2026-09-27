# frozen_string_literal: true

module DPay
  module Internal
    module ErrorMapper
      DEFAULT_MESSAGE = "Unexpected API error"

      module_function

      def map(response)
        decoded = response.decode_json
        data = decoded.is_a?(Hash) ? decoded : {}
        message = extract_message(data)

        return rate_limit(response, message) if response.status == 429

        error_class(response.status).new(
          message,
          response.status,
          extract_code(data),
          normalize_field_errors(data["errors"]),
          response.body,
          data["reason"].is_a?(String) ? data["reason"] : nil
        )
      end

      # "code" (Cards API, webhooks, Connect: CHECKSUM_REQUIRED, WEBHOOK_URL_INVALID, ...), then legacy "errorcode".
      def extract_code(data)
        return data["code"] if data["code"].is_a?(String)
        return data["errorcode"] if data["errorcode"].is_a?(String)

        nil
      end

      def error_class(status)
        case status
        when 401 then AuthenticationError
        when 403 then AccessDeniedError
        when 404 then NotFoundError
        when 400, 422 then InvalidRequestError
        else status >= 500 ? ApiServerError : ApiError
        end
      end

      def extract_message(data)
        return data["message"] if data["message"].is_a?(String)
        return data["msg"] if data["msg"].is_a?(String)

        DEFAULT_MESSAGE
      end

      def rate_limit(response, message)
        RateLimitError.new(
          message,
          response.status,
          int_header(response, "Retry-After"),
          int_header(response, "X-RateLimit-Limit"),
          int_header(response, "X-RateLimit-Remaining"),
          response.body
        )
      end

      def normalize_field_errors(errors)
        pairs = case errors
                when Array then errors.each_with_index.map { |messages, index| [index, messages] }
                when Hash then errors.to_a
                else return {}
                end

        pairs.each_with_object({}) do |(field, messages), result|
          normalized = normalize_messages(messages)
          result[PHP.strval(field)] = normalized unless normalized.nil?
        end
      end

      def normalize_messages(messages)
        case messages
        when String then [messages]
        when Array then messages.select { |message| scalar?(message) }.map { |message| PHP.strval(message) }
        end
      end

      def scalar?(value)
        value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
      end

      def int_header(response, name)
        value = response.header(name)
        return nil if value.nil?

        match = /\A\s*[+-]?\d+/.match(value.to_s)
        return 0 if match.nil?

        digits = match[0]
        digits.nil? ? 0 : digits.strip.to_i
      end
    end
  end
end
