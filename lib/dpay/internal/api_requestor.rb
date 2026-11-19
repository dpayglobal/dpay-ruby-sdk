# frozen_string_literal: true

module DPay
  module Internal
    class ApiRequestor
      USER_AGENT = "dpay-ruby-sdk/#{VERSION} ruby/#{RUBY_VERSION}".freeze
      HEADER_NAME = /\A[A-Za-z0-9-]+\z/
      HEADER_VALUE_FORBIDDEN = /[\x00-\x1F\x7F]/

      attr_reader :config, :checksum

      def initialize(config, http_client)
        @config = config
        @http_client = http_client
        @checksum = ChecksumCalculator.new(config.secret_hash)
      end

      def service
        @config.service
      end

      # Your service name for a panel (/api/v1/pbl/*) request body, trimmed like the API trims it (ServerTrim).
      def panel_service
        ServerTrim.required(@config.service, "service")
      end

      # A panel (/api/v1/pbl/*) body ready to send: every string trimmed the way the API trims it before it verifies
      # the checksum (ServerTrim), then signed with the ordered-body checksum over the values as sent.
      def sign_panel_body(body)
        # @type var trimmed: Hash[String, untyped]
        trimmed = ServerTrim.trim_strings(body)
        trimmed["checksum"] = @checksum.ordered_body(trimmed)

        trimmed
      end

      # headers: extra request headers (e.g. DigitalPayments-PSP-Message-ID).
      def post_json(host, path, body, headers = {})
        decode(send_request("POST", host, path, body, headers))
      end

      def get_json(host, path)
        decode(send_request("GET", host, path, nil))
      end

      def get_text(host, path)
        send_request("GET", host, path, nil).body
      end

      def send_request(method, host, path, body, headers = {})
        response = send_raw(method, host, path, body, headers)
        raise map_error(response) if response.status >= 400

        response
      end

      # extra_headers are sent after the SDK headers; names must match ^[A-Za-z0-9-]+$ and values must not contain
      # control characters (no header injection) - otherwise InvalidArgumentError and nothing is sent.
      def send_raw(method, host, path, body, extra_headers = {})
        # @type var headers: Hash[String, String]
        headers = { "Accept" => "application/json", "User-Agent" => USER_AGENT }
        extra_headers.each do |name, value|
          unless name.is_a?(String) && HEADER_NAME.match?(name) &&
                 value.is_a?(String) && !HEADER_VALUE_FORBIDDEN.match?(value)
            raise InvalidArgumentError, %(Invalid request header "#{name}")
          end

          headers[name] = value
        end
        encoded = nil

        unless body.nil?
          headers["Content-Type"] = "application/json"
          encoded = PHP.json_encode(body)
        end

        @http_client.request(HTTP::Request.new(method, @config.base_urls.resolve(host) + path, headers, encoded))
      end

      def map_error(response)
        ErrorMapper.map(response)
      end

      private

      def decode(response)
        decoded = response.decode_json
        return decoded unless decoded.nil?

        raise ApiServerError.new("Invalid JSON in API response", response.status, nil, {}, response.body)
      end
    end
  end
end
