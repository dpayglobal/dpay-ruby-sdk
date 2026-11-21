# frozen_string_literal: true

module DPay
  class ApplePayRequest
    INIT = "APPLE_PAY_INIT"
    PAY = "APPLE_PAY"

    def self.init(device_info)
      new(INIT, nil, device_info)
    end

    def self.pay(token, device_info)
      new(PAY, token, device_info)
    end

    def initialize(x_pay_type, token, device_info)
      @x_pay_type = x_pay_type
      @token = token
      @device_info = device_info
      @channel_id = nil
      @email = nil
    end

    # Payer's email (sent with the APPLE_PAY call, like for Google Pay).
    def with_email(email)
      @email = email
      self
    end

    def with_channel_id(channel_id)
      @channel_id = channel_id
      self
    end

    def to_body
      body = {}
      body["email"] = @email unless @email.nil?
      body["channelId"] = @channel_id unless @channel_id.nil?
      body["xPayType"] = @x_pay_type
      body["xPayToken"] = @token unless @token.nil?
      body["deviceInfo"] = @device_info.to_h

      body
    end
  end
end
