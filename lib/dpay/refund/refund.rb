# frozen_string_literal: true

module DPay
  class Refund
    attr_reader :message, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @accepted = data["status"] == "success" && data["refund"] == true
      @message = Internal::Coerce.string(data["message"])
      freeze
    end

    def accepted?
      @accepted
    end
  end
end
