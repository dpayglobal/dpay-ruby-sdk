# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"

module DPay
  module HTTP
    class NetHTTPClient < Client
      CONNECT_TIMEOUT = 10

      NETWORK_ERRORS = [
        Timeout::Error, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse
      ].freeze

      def initialize(timeout = 30)
        super()
        @timeout = timeout
      end

      def request(api_request)
        uri = URI.parse(api_request.url)
        raise TransportError, "Unsupported URL scheme: #{api_request.url}" unless uri.is_a?(URI::HTTP)

        host = uri.host
        raise TransportError, "URL has no host: #{api_request.url}" if host.nil?

        http = Net::HTTP.new(host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = CONNECT_TIMEOUT
        http.read_timeout = @timeout
        http.write_timeout = @timeout

        response = http.request(build_request(uri, api_request))

        Response.new(response.code.to_i, response.each_header.to_h, response.body.to_s)
      rescue *NETWORK_ERRORS => e
        raise TransportError, "HTTP transport error: #{e.class}: #{e.message}"
      end

      private

      def build_request(uri, api_request)
        klass = Net::HTTP.const_get(api_request.method.to_s.capitalize)
        request = klass.new(uri.request_uri)
        api_request.headers.each { |name, value| request[name] = value }
        request.body = api_request.body unless api_request.body.nil?
        request
      end
    end
  end
end
