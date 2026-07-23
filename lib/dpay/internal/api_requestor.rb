# frozen_string_literal: true

module DPay
  module Internal
    class ApiRequestor
      USER_AGENT = "dpay-ruby-sdk/#{VERSION} ruby/#{RUBY_VERSION}".freeze

      attr_reader :config, :checksum

      def initialize(config, http_client)
        @config = config
        @http_client = http_client
        @checksum = ChecksumCalculator.new(config.secret_hash)
      end

      def service
        @config.service
      end

      def post_json(host, path, body)
        decode(send_request("POST", host, path, body))
      end

      def get_json(host, path)
        decode(send_request("GET", host, path, nil))
      end

      def get_text(host, path)
        send_request("GET", host, path, nil).body
      end

      def send_request(method, host, path, body)
        response = send_raw(method, host, path, body)
        raise map_error(response) if response.status >= 400

        response
      end

      def send_raw(method, host, path, body)
        headers = { "Accept" => "application/json", "User-Agent" => USER_AGENT }
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
