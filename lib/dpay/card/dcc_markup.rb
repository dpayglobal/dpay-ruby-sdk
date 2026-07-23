# frozen_string_literal: true

module DPay
  class DccMarkup
    attr_reader :rate, :additional_info

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      rate = data["rate"]
      @rate = rate.is_a?(Integer) || rate.is_a?(Float) ? rate.to_f : 0.0
      @additional_info = data["additionalInfo"].is_a?(String) ? data["additionalInfo"] : nil
      freeze
    end
  end
end
