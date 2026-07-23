# frozen_string_literal: true

module DPay
  class PayoutReceiver
    attr_reader :nrb, :title, :amount, :service, :receiver_name, :receiver_address, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @nrb = data["nrb"].is_a?(String) ? data["nrb"] : nil
      @title = data["title"].is_a?(String) ? data["title"] : nil
      @amount = Money.try_from_api_number(data["amount"], Currency::PLN)
      @service = data["service"].is_a?(String) ? data["service"] : nil
      @receiver_name = data["receiverName"].is_a?(String) ? data["receiverName"] : nil
      @receiver_address = data["receiverAddress"].is_a?(String) ? data["receiverAddress"] : nil
      freeze
    end
  end
end
