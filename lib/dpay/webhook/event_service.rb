# frozen_string_literal: true

module DPay
  # Events API: the event history of the service (the same envelopes as webhooks), newest first. Use it to catch up
  # after an outage of your webhook endpoint.
  class EventService
    PATH = "/api/v1_0/events"
    STARTING_AFTER = /\Aevt_[0-9a-z]{26}\z/
    DATE_FIELDS = %w[created_from created_to].freeze
    LIMIT = (1..100)

    def initialize(api)
      @api = api
    end

    # params (String or Symbol keys): types, created_from, created_to, starting_after, limit. timestamp: Unix time
    # for the checksum (defaults to now; the API accepts +/- 300 s).
    def list(params = {}, timestamp = nil)
      options = params.transform_keys(&:to_s)
      timestamp = Time.now.to_i if timestamp.nil?
      raise InvalidArgumentError, "timestamp must be an Integer (Unix time)" unless timestamp.is_a?(Integer)

      body = { "service" => @api.service, "timestamp" => timestamp }
      append_types(body, options["types"])
      DATE_FIELDS.each { |field| body[field] = options[field] unless options[field].nil? }
      append_starting_after(body, options["starting_after"])
      append_limit(body, options["limit"])
      body["checksum"] = @api.checksum.secret_second(@api.service, [timestamp.to_s])

      EventPage.from_api(@api.post_json(Internal::BaseUrls::API_PAYMENTS, PATH, body))
    end

    # Iterates over all matching events page by page (newest first). Without a block returns an Enumerator.
    def iterate(params = {}, &block)
      return enum_for(:iterate, params) if block.nil?

      options = params.transform_keys(&:to_s)
      loop do
        page = list(options)
        page.data.each(&block)
        options["starting_after"] = page.next_starting_after
        break unless page.has_more? && !options["starting_after"].nil?
      end

      nil
    end

    private

    def append_types(body, types)
      return if types.nil?
      unless types.is_a?(Array) && !types.empty? && types.uniq.size == types.size
        raise InvalidArgumentError, "Event types must be a non-empty list of distinct types"
      end

      WebhookEventType.assert_allowed(types, WebhookEventType::MERCHANT, "the Events API")
      body["types"] = types.dup
    end

    def append_starting_after(body, starting_after)
      return if starting_after.nil?
      unless starting_after.is_a?(String) && STARTING_AFTER.match?(starting_after)
        raise InvalidArgumentError, "starting_after must be an event id (evt_...)"
      end

      body["starting_after"] = starting_after
    end

    def append_limit(body, limit)
      return if limit.nil?
      raise InvalidArgumentError, "limit must be between 1 and 100" unless limit.is_a?(Integer) && LIMIT.cover?(limit)

      body["limit"] = limit
    end
  end
end
