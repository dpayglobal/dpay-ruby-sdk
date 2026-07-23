# frozen_string_literal: true

module DPay
  class PayoutDetails
    attr_reader :id, :state, :net, :fee, :gross, :creation_date, :nrb, :decline_reason, :decline_status,
                :receiver, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @id = Internal::Coerce.integer(data["id"])
      @state = Internal::Coerce.optional_integer(data["state"])
      @net = Internal::Coerce.money(data["net"])
      @fee = Internal::Coerce.money(data["fee"])
      @gross = Internal::Coerce.money(data["gross"])
      @creation_date = data["creation_date"].is_a?(String) ? data["creation_date"] : nil
      @direct_settlement = Internal::Coerce.integer(data["direct_settlement"]) == 1
      @nrb = data["nrb"].is_a?(String) ? data["nrb"] : nil
      @declined = Internal::Coerce.integer(data["declined"]) == 1
      @decline_reason = data["decline_reason"].is_a?(String) ? data["decline_reason"] : nil
      @decline_status = data["decline_status"].is_a?(String) ? data["decline_status"] : nil
      @receiver = data["receiver"].is_a?(Hash) ? PayoutReceiver.from_api(data["receiver"]) : nil
      freeze
    end

    def waiting?
      state = @state
      !state.nil? && state.zero?
    end

    def processed?
      @state == 1
    end

    def failed?
      @state == -1
    end

    def direct_settlement?
      @direct_settlement
    end

    def declined?
      @declined
    end
  end
end
