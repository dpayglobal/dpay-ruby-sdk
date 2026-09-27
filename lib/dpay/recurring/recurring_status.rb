# frozen_string_literal: true

module DPay
  class RecurringStatus
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    UNREGISTERED = "UNREGISTERED"
    EXPIRED = "EXPIRED"
    DECLINED = "DECLINED"

    ALL = [ACTIVE, INACTIVE, UNREGISTERED, EXPIRED, DECLINED].freeze

    # payment_method: the "method" field, e.g. "blik" (renamed so it does not shadow Object#method).
    # status: ACTIVE, INACTIVE (waiting for the customer), UNREGISTERED, EXPIRED, DECLINED or nil.
    attr_reader :alias, :payment_method, :status, :expiration_date, :registration, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @alias = string(data["alias"]) || ""
      @payment_method = string(data["method"])
      @status = string(data["status"])
      @expiration_date = string(data["expiration_date"])
      registration = data["registration"]
      @registration = registration.is_a?(Hash) ? RecurringRegistrationInfo.from_api(registration) : nil
      freeze
    end

    def active?
      @status == ACTIVE
    end

    private

    def string(value)
      value.is_a?(String) ? value : nil
    end
  end
end
