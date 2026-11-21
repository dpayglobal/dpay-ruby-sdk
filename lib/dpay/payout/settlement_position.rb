# frozen_string_literal: true

module DPay
  # A payment settled by a payout (transactions[] of withdraws/details/full).
  class SettlementPosition
    # payment_id: payment ID - the same as in the IPN; nil when unknown. date: when the payment was made.
    # net: amount credited to you, fee: commission charged on this payment, gross: amount paid by the payer.
    # custom: the custom value from the registration, as in the IPN. ipksef: KSeF payment identifier of a payment
    # settled with an e-invoice.
    attr_reader :payment_id, :date, :net, :fee, :gross, :service_id, :service_name, :custom, :ipksef, :raw

    def self.from_api(data, currency)
      new(data, currency)
    end

    def initialize(data, currency)
      @raw = data
      @payment_id = string(data["payment_id"])
      @date = string(data["date"])
      @net = Internal::Coerce.money(data["net"], currency)
      @fee = Internal::Coerce.money(data["fee"], currency)
      @gross = Internal::Coerce.money(data["gross"], currency)
      @service_id = data["service_id"].is_a?(Integer) ? data["service_id"] : nil
      @service_name = string(data["service_name"])
      @custom = string(data["custom"])
      @ipksef = string(data["ipksef"])
      freeze
    end

    private

    def string(value)
      value.is_a?(String) ? value : nil
    end
  end
end
