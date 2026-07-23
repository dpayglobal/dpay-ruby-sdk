# frozen_string_literal: true

module DPay
  class BlikRecurringStatus
    ACTIVE = "ACTIVE"

    attr_reader :alias_value, :alias_type, :status, :expiration_date, :registration, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @alias_value = Internal::Coerce.string(data["alias_value"]) || ""
      @alias_type = Internal::Coerce.string(data["alias_type"]) || BlikAliasType::PAYID
      @status = data["status"].is_a?(String) ? data["status"] : nil
      @expiration_date = data["expiration_date"].is_a?(String) ? data["expiration_date"] : nil
      registration = data["registration"]
      @registration = registration.is_a?(Hash) ? BlikRecurringRegistrationInfo.from_api(registration) : nil
      freeze
    end

    def active?
      @status == ACTIVE
    end
  end
end
