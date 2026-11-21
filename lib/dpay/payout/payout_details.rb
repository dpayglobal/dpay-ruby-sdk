# frozen_string_literal: true

module DPay
  # Payout header: withdraws/details, and "settlement" of withdraws/details/full (PayoutSettlement). Amounts are in
  # #currency - currency_code when the API sends it, otherwise PLN.
  class PayoutDetails
    # export_date: when the transfer was sent to the bank (withdraws/details/full only); nil until then.
    attr_reader :id, :state, :net, :fee, :gross, :currency, :creation_date, :export_date, :nrb, :decline_reason,
                :decline_status, :receiver, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @currency = Internal::ObjectFields.currency(data, "currency_code")
      @id = Internal::Coerce.integer(data["id"])
      @state = Internal::Coerce.optional_integer(data["state"])
      @net = Internal::Coerce.money(data["net"], @currency)
      @fee = Internal::Coerce.money(data["fee"], @currency)
      @gross = Internal::Coerce.money(data["gross"], @currency)
      @creation_date = data["creation_date"].is_a?(String) ? data["creation_date"] : nil
      @export_date = data["export_date"].is_a?(String) ? data["export_date"] : nil
      # The API sends its 0/1 flags as JSON integers - only the Integer 1 is true
      @direct_settlement = json_one?(data["direct_settlement"])
      @nrb = data["nrb"].is_a?(String) ? data["nrb"] : nil
      @declined = json_one?(data["declined"])
      @decline_reason = data["decline_reason"].is_a?(String) ? data["decline_reason"] : nil
      @decline_status = data["decline_status"].is_a?(String) ? data["decline_status"] : nil
      @paysafecard = json_one?(data["paysafecard"])
      @receiver = data["receiver"].is_a?(Hash) ? PayoutReceiver.from_api(data["receiver"], @currency) : nil
      freeze
    end

    def waiting?
      @state == PayoutState::WAITING
    end

    def processed?
      @state == PayoutState::PROCESSED
    end

    def failed?
      @state == PayoutState::FAILED
    end

    # Paysafecard payout (paysafecard is the JSON integer 1; sent only for regular, non-direct settlements).
    def paysafecard?
      @paysafecard
    end

    def direct_settlement?
      @direct_settlement
    end

    def declined?
      @declined
    end

    private

    def json_one?(value)
      value.is_a?(Integer) && value == 1
    end
  end
end
