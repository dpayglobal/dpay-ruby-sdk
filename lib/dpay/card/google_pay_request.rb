# frozen_string_literal: true

module DPay
  class GooglePayRequest
    def self.create(token, device_info)
      new(token, device_info)
    end

    def initialize(token, device_info)
      @token = token
      @device_info = device_info
      @leading = {}
    end

    def with_email(email)
      @leading["email"] = email
      self
    end

    def with_channel_id(channel_id)
      @leading["channelId"] = channel_id
      self
    end

    def to_body
      body = {}
      %w[email channelId].each { |key| body[key] = @leading[key] if @leading.key?(key) }
      body["xPayType"] = "GOOGLE_PAY"
      body["xPayToken"] = @token
      body["deviceInfo"] = @device_info.to_h

      body
    end
  end
end
