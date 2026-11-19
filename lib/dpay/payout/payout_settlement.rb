# frozen_string_literal: true

module DPay
  # payouts.details_full: the payout header, the totals of the WHOLE settlement and one page of the payments it
  # settles. A payout of exactly one payment returns one position; a payout with unknown positions returns none.
  class PayoutSettlement
    # settlement: payout header (DPay::PayoutDetails: state, amounts, currency, account or receiver, decline reason).
    # summary_net, summary_fee, summary_gross: totals of the whole settlement; summary_count: number of its positions.
    # positions: the positions of this page (DPay::SettlementPosition).
    attr_reader :settlement, :summary_net, :summary_fee, :summary_gross, :summary_count, :positions, :meta, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @settlement = PayoutDetails.from_api(data["settlement"].is_a?(Hash) ? data["settlement"] : {})
      currency = @settlement.currency
      summary = data["summary"].is_a?(Hash) ? data["summary"] : {}
      @summary_net = Internal::Coerce.money(summary["net"], currency)
      @summary_fee = Internal::Coerce.money(summary["fee"], currency)
      @summary_gross = Internal::Coerce.money(summary["gross"], currency)
      count = summary["count"]
      @summary_count = Internal::PHP.numeric?(count) ? Internal::PHP.numeric_to_i(count) : 0
      @positions = Internal::Coerce.list(data["transactions"])
                                   .map { |position| SettlementPosition.from_api(position, currency) }.freeze
      @meta = PageMeta.from_api(data["meta"].is_a?(Hash) ? data["meta"] : {})
      freeze
    end
  end
end
