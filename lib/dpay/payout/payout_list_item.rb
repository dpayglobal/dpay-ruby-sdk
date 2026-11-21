# frozen_string_literal: true

module DPay
  # One payout of payouts.list. The account, receiver and decline reason are in payouts.details(item.id).
  class PayoutListItem
    # id: use as withdraw_id in payouts.details and payouts.details_full. type: standard, direct or paysafecard
    # (PayoutType). state: 0 waiting, 1 processed, -1 failure (PayoutState). export_date: when the transfer was sent
    # to the bank; nil until then. Amounts in #currency (currency_code, PLN when missing).
    attr_reader :id, :type, :state, :net, :fee, :gross, :currency, :creation_date, :export_date, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @currency = Internal::ObjectFields.currency(data, "currency_code")
      @id = integer(data["id"])
      @type = data["type"].is_a?(String) ? data["type"] : nil
      @state = integer(data["state"])
      @net = Internal::Coerce.money(data["net"], @currency)
      @fee = Internal::Coerce.money(data["fee"], @currency)
      @gross = Internal::Coerce.money(data["gross"], @currency)
      @creation_date = data["creation_date"].is_a?(String) ? data["creation_date"] : nil
      @export_date = data["export_date"].is_a?(String) ? data["export_date"] : nil
      # declined is the JSON integer 1 (the API casts it with (int))
      @declined = data["declined"].is_a?(Integer) && data["declined"] == 1
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

    def declined?
      @declined
    end

    private

    def integer(value)
      Internal::PHP.numeric?(value) ? Internal::PHP.numeric_to_i(value) : 0
    end
  end
end
