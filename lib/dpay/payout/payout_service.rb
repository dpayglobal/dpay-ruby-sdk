# frozen_string_literal: true

module DPay
  # Payouts (withdrawals) of your account. Every endpoint signs the body in the order it is sent:
  # sha256(value1|value2|...|SecretHash) - optional fields are sent only when set, strings trimmed like the API trims
  # them (Internal::ServerTrim).
  class PayoutService
    LIST_FILTERS = %w[date_from date_to state type].freeze
    DATE_FILTERS = %w[date_from date_to].freeze
    LIST_PER_PAGE_MAX = 200
    DETAILS_FULL_PER_PAGE_MAX = 500

    def initialize(api)
      @api = api
    end

    def details(withdraw_id, timestamp = nil)
      # @type var body: Hash[String, untyped]
      body = { "service" => @api.panel_service }
      body["timestamp"] = timestamp unless timestamp.nil?
      body["withdraw_id"] = withdraw_id

      data = @api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/withdraws/details", @api.sign_panel_body(body))
      unless data.is_a?(Hash) && Internal::Coerce.integer(data["id"]).positive?
        raise ApiServerError.new("API response carries no payout details", 200, nil, {}, Internal::PHP.json_encode(data))
      end

      PayoutDetails.from_api(data)
    end

    # Your payouts, newest first - the source of withdraw_id.
    #
    # filters (String or Symbol keys): date_from, date_to - creation date range (Strings: any date or date-time, e.g.
    # "2026-07-01", "2026-07-31 23:59:59"; sent trimmed like every string of a panel request), state (PayoutState,
    # Integer), type (PayoutType, String) - a value of another type raises InvalidArgumentError; nil counts as not set.
    # per_page: 1-200 (API default 50).
    def list(filters = {}, page = nil, per_page = nil)
      # @type var body: Hash[String, untyped]
      body = { "service" => @api.panel_service }
      body.merge!(filter_body(filters))
      add_page(body, page, per_page, LIST_PER_PAGE_MAX)
      body = @api.sign_panel_body(body)

      PayoutPage.from_api(@api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/withdraws", body))
    end

    # Iterates over all matching payouts page by page (newest first). Without a block returns an Enumerator.
    def iterate(filters = {}, per_page = nil, &block)
      return enum_for(:iterate, filters, per_page) if block.nil?

      page = 1
      loop do
        result = list(filters, page, per_page)
        result.items.each(&block)
        page += 1
        break unless result.has_more?
      end

      nil
    end

    # The payout with the payments it settles: header, totals of the whole settlement and one page of positions.
    # per_page: 1-500 (API default 100).
    def details_full(withdraw_id, page = nil, per_page = nil)
      # @type var body: Hash[String, untyped]
      body = { "service" => @api.panel_service, "withdraw_id" => withdraw_id }
      add_page(body, page, per_page, DETAILS_FULL_PER_PAGE_MAX)
      body = @api.sign_panel_body(body)

      PayoutSettlement.from_api(@api.post_json(Internal::BaseUrls::PANEL, "/api/v1/pbl/withdraws/details/full", body))
    end

    private

    # Validates the filters of #list - any Hash, as callers may pass anything - and returns them as body fields in the
    # order the checksum signs them. Wrong keys, types and values raise InvalidArgumentError.
    def filter_body(filters)
      raise InvalidArgumentError, "filters must be a Hash" unless filters.is_a?(Hash)

      options = filters.transform_keys(&:to_s)
      unknown = options.keys - LIST_FILTERS
      raise InvalidArgumentError, %(Unknown payout filter "#{unknown.join('", "')}") unless unknown.empty?

      # @type var body: Hash[String, untyped]
      body = {}
      DATE_FILTERS.each do |field|
        # The API trims strings before it verifies the checksum - an untrimmed value would fail with 401
        body[field] = Internal::ServerTrim.required(options[field], field) unless options[field].nil?
      end
      unless options["state"].nil?
        raise InvalidArgumentError, "state must be an integer" unless options["state"].is_a?(Integer)

        PayoutState.assert_valid(options["state"])
        body["state"] = options["state"]
      end
      unless options["type"].nil?
        raise InvalidArgumentError, "type must be a string" unless options["type"].is_a?(String)

        PayoutType.assert_valid(options["type"])
        body["type"] = options["type"]
      end

      body
    end

    def add_page(body, page, per_page, max_per_page)
      unless page.nil?
        raise InvalidArgumentError, "page must be at least 1" unless page.is_a?(Integer) && page >= 1

        body["page"] = page
      end
      return if per_page.nil?
      unless per_page.is_a?(Integer) && per_page.between?(1, max_per_page)
        raise InvalidArgumentError, "per_page must be between 1 and #{max_per_page}"
      end

      body["per_page"] = per_page
    end
  end
end
