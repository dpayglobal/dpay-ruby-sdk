# frozen_string_literal: true

module DPay
  class BlikAlias
    ACTIVE = "ACTIVE"

    attr_reader :alias_value, :alias_type, :status, :expiration_date, :apps, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @alias_value = Internal::Coerce.string(data["alias_value"]) || ""
      @alias_type = Internal::Coerce.string(data["alias_type"]) || BlikAliasType::UID
      @status = data["status"].is_a?(String) ? data["status"] : nil
      @expiration_date = data["expiration_date"].is_a?(String) ? data["expiration_date"] : nil
      @apps = Internal::Coerce.list(data["apps"]).map { |app| BlikApp.from_api(app) }
      freeze
    end

    def active?
      @status == ACTIVE
    end
  end
end
