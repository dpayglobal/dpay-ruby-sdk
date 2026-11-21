# frozen_string_literal: true

module DPay
  # Payload of an "alias_update" IPN: a BLIK OneClick alias (alias type UID) or a recurring payment (PAYID) changed
  # its status. Sent to alias_ipn_url from the registration, or to url_ipn without it.
  #
  # The signature covers only id, type and version - none of the fields below. Anyone who has seen one alias_update
  # of a payment can replay it with a different status, so before acting on a change (e.g. stopping a subscription)
  # confirm the current state with client.recurring.status or client.blik.alias.
  class AliasUpdate
    CHANGE_REGISTER = "ALIAS_REGISTER"
    CHANGE_UPDATE = "ALIAS_UPDATE"
    CHANGE_UNREGISTER = "ALIAS_UNREGISTER"
    CHANGE_EXPIRED = "ALIAS_EXPIRED"
    CHANGE_DECLINED = "ALIAS_DECLINED"

    ALIAS_TYPE_UID = "UID"
    ALIAS_TYPE_PAYID = "PAYID"

    STATUS_ACTIVE = "ACTIVE"
    STATUS_INACTIVE = "INACTIVE"
    STATUS_UNREGISTERED = "UNREGISTERED"
    STATUS_EXPIRED = "EXPIRED"
    STATUS_DECLINED = "DECLINED"

    # change_type: ALIAS_REGISTER, ALIAS_UPDATE, ALIAS_UNREGISTER, ALIAS_EXPIRED or ALIAS_DECLINED.
    # alias_type: UID (BLIK OneClick) or PAYID (recurring payment).
    # alias_status: ACTIVE, INACTIVE, UNREGISTERED, EXPIRED or DECLINED.
    # alias_key: alias identifier at BLIK - not the alias value you send with payments.
    attr_reader :change_type, :alias_type, :alias_status, :alias_key, :alias_label, :alias_expire_at,
                :change_reason_category, :change_reason_message, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @change_type = string(data["change_type"])
      @alias_type = string(data["alias_type"])
      @alias_status = string(data["alias_status"])
      @alias_key = string(data["alias_key"])
      @alias_label = string(data["alias_label"])
      @alias_expire_at = string(data["alias_expire_at"])
      @change_reason_category = string(data["change_reason_category"])
      @change_reason_message = string(data["change_reason_message"])
      freeze
    end

    def active?
      @alias_status == STATUS_ACTIVE
    end

    private

    def string(value)
      value.is_a?(String) || value.is_a?(Integer) ? value.to_s : nil
    end
  end
end
