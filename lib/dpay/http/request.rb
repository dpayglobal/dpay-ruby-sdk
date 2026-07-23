# frozen_string_literal: true

module DPay
  module HTTP
    class Request
      attr_reader :method, :url, :headers, :body

      def initialize(method, url, headers = {}, body = nil)
        @method = method
        @url = url
        @headers = headers.freeze
        @body = body
        freeze
      end
    end
  end
end
