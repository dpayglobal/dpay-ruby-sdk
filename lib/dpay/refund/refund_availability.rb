# frozen_string_literal: true

module DPay
  class RefundAvailability
    attr_reader :message, :http_status, :raw

    def self.from_api(data, http_status = nil)
      new(data, http_status)
    end

    def initialize(data, http_status = nil)
      @raw = data
      @available = data["refund"] == true
      @message = Internal::Coerce.string(data["message"])
      @http_status = http_status
      freeze
    end

    def available?
      @available
    end
  end
end
