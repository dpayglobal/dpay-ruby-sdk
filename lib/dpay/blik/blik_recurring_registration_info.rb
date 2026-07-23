# frozen_string_literal: true

module DPay
  class BlikRecurringRegistrationInfo
    attr_reader :model, :frequency, :limit_amt, :tot_limit_amt, :limit_amt_fixed, :init_date, :label,
                :registered_at, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @model = data["model"].is_a?(String) ? data["model"] : nil
      @frequency = data["frequency"].is_a?(String) ? data["frequency"] : nil
      @limit_amt = data["limit_amt"].is_a?(Integer) ? data["limit_amt"] : nil
      @tot_limit_amt = data["tot_limit_amt"].is_a?(Integer) ? data["tot_limit_amt"] : nil
      fixed = data["is_limit_amt_fixed"]
      @limit_amt_fixed = fixed.is_a?(TrueClass) || fixed.is_a?(FalseClass) ? fixed : nil
      @init_date = data["init_date"].is_a?(String) ? data["init_date"] : nil
      @label = data["label"].is_a?(String) ? data["label"] : nil
      @registered_at = data["registered_at"].is_a?(String) ? data["registered_at"] : nil
      freeze
    end
  end
end
