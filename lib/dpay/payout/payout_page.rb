# frozen_string_literal: true

module DPay
  # One page of payouts.list, newest payouts first.
  class PayoutPage
    attr_reader :items, :meta, :raw

    def self.from_api(response)
      new(response)
    end

    def initialize(response)
      @raw = response
      @items = Internal::Coerce.list(response["withdraws"]).map { |item| PayoutListItem.from_api(item) }.freeze
      @meta = PageMeta.from_api(response["meta"].is_a?(Hash) ? response["meta"] : {})
      freeze
    end

    def has_more? # rubocop:disable Naming/PredicatePrefix
      !@items.empty? && @meta.has_more?
    end
  end
end
