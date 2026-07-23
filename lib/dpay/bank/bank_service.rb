# frozen_string_literal: true

module DPay
  class BankService
    PATH = "/api/v1/pbl/banks"

    def initialize(api)
      @api = api
    end

    def all
      map_banks(@api.get_json(Internal::BaseUrls::PANEL, PATH))
    end

    def for_service(timestamp = nil)
      body = { "service" => @api.service, "timestamp" => timestamp || Time.now.to_i }
      body["checksum"] = @api.checksum.ordered_body(body.values)

      map_banks(@api.post_json(Internal::BaseUrls::PANEL, PATH, body))
    end

    private

    def map_banks(data)
      Internal::Coerce.list(data).map { |bank| Bank.from_api(bank) }
    end
  end
end
