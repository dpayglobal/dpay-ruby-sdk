# frozen_string_literal: true

require "json"

module DPay
  module HTTP
    class Response
      attr_reader :status, :headers, :body

      def initialize(status, headers, body)
        @status = status
        @headers = headers.each_with_object({}) { |(name, value), result| result[name.to_s.downcase] = value }.freeze
        @body = body
        freeze
      end

      def header(name)
        @headers[name.to_s.downcase]
      end

      def decode_json
        decoded = JSON.parse(@body.to_s)
        decoded.is_a?(Hash) || decoded.is_a?(Array) ? decoded : nil
      rescue JSON::ParserError
        nil
      end
    end
  end
end
