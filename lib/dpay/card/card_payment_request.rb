# frozen_string_literal: true

module DPay
  class CardPaymentRequest
    def self.create(device_info)
      new(device_info)
    end

    def initialize(device_info)
      @device_info = device_info
      @leading = {}
      @trailing = {}
    end

    def with_email(email)
      @leading["email"] = email
      self
    end

    def with_channel_id(channel_id)
      @leading["channelId"] = channel_id
      self
    end

    def with_card_holder(first_name, last_name)
      @leading["cardHolderFirstName"] = first_name
      @leading["cardHolderLastName"] = last_name
      self
    end

    def with_encrypted_card_data(encrypted_card_data)
      @leading["encryptedCardData"] = encrypted_card_data
      self
    end

    def with_three_ds_confirmed(confirmed)
      @trailing["threeDsConfirmed"] = confirmed
      self
    end

    def with_dcc_decision(decision)
      DccDecision.assert_valid(decision)
      @trailing["dccDecision"] = decision
      self
    end

    def to_body
      body = {}

      %w[email channelId cardHolderFirstName cardHolderLastName encryptedCardData].each do |key|
        body[key] = @leading[key] if @leading.key?(key)
      end
      body["deviceInfo"] = @device_info.to_h
      %w[threeDsConfirmed dccDecision].each { |key| body[key] = @trailing[key] if @trailing.key?(key) }

      body
    end
  end
end
