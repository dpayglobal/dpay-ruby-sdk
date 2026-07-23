# frozen_string_literal: true

require "json"

module DPay
  module Testing
    class MockHttpClient < HTTP::Client
      attr_reader :queued, :requests

      def initialize
        super
        @queued = []
        @requests = []
      end

      def queue(response)
        @queued << response
        self
      end

      def queue_json(status, body, headers = {})
        queue(HTTP::Response.new(status, { "content-type" => "application/json" }.merge(headers),
                                 Internal::PHP.json_encode(body)))
      end

      def queue_text(status, body, headers = {})
        queue(HTTP::Response.new(status, headers, body))
      end

      def request(api_request)
        @requests << api_request
        raise "MockHttpClient queue is empty" if @queued.empty?

        @queued.shift
      end

      def last_request
        raise "MockHttpClient recorded no requests" if @requests.empty?

        @requests.last
      end

      def last_request_body
        body = last_request.body
        raise "MockHttpClient last request has no body" if body.nil?

        JSON.parse(body)
      end
    end
  end
end
