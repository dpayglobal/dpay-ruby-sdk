# frozen_string_literal: true

module DPay
  class BlikService
    def initialize(api)
      @api = api
    end

    def alias(alias_value, alias_type = BlikAliasType::UID)
      data = @api.post_json(
        Internal::BaseUrls::API_PAYMENTS,
        "/api/v1_0/payments/blik/aliases",
        alias_body(alias_value, alias_type)
      )

      BlikAlias.from_api(payload(data))
    end

    def unregister_alias(alias_value, alias_type = BlikAliasType::UID, reason = nil)
      body = alias_body(alias_value, alias_type, reason)
      @api.post_json(Internal::BaseUrls::API_PAYMENTS, "/api/v1_0/payments/blik/aliases/unregister", body)

      nil
    end

    def recurring_status(alias_value)
      body = { "service" => @api.service, "alias_value" => alias_value }
      body["checksum"] = @api.checksum.secret_second(@api.service, [alias_value])

      data = @api.post_json(Internal::BaseUrls::API_PAYMENTS, "/api/v1_0/payments/blik/recurring/status", body)

      BlikRecurringStatus.from_api(payload(data))
    end

    private

    def alias_body(alias_value, alias_type, reason = nil)
      BlikAliasType.assert_valid(alias_type)

      body = { "service" => @api.service, "alias_value" => alias_value, "alias_type" => alias_type }
      body["reason"] = reason unless reason.nil?
      body["checksum"] = @api.checksum.secret_second(@api.service, [alias_value])

      body
    end

    def payload(data)
      data["data"].is_a?(Hash) ? data["data"] : {}
    end
  end
end
