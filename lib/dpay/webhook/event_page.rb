# frozen_string_literal: true

module DPay
  class EventPage
    # data: events, newest first. Re-encoded by the API - do not verify webhook signatures on them.
    attr_reader :data, :next_starting_after, :raw

    def self.from_api(response)
      new(response)
    end

    def initialize(response)
      @raw = response
      @data = Internal::Coerce.list(response["data"]).map { |event| WebhookEvent.from_api(event) }.freeze
      @has_more = response["has_more"] == true
      next_starting_after = response["next_starting_after"]
      @next_starting_after = next_starting_after.is_a?(String) ? next_starting_after : nil
      freeze
    end

    def has_more? # rubocop:disable Naming/PredicatePrefix
      @has_more
    end
  end
end
