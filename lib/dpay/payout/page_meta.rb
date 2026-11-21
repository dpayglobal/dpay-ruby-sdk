# frozen_string_literal: true

module DPay
  # "meta" of a paginated payout response: the page returned, its size and the totals of the whole result.
  class PageMeta
    # page: the page that was returned - echoed back even beyond the last page. total: number of items in the whole
    # result. total_pages: 0 when the result is empty.
    attr_reader :page, :per_page, :total, :total_pages

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @page = integer(data["page"], 1)
      @per_page = integer(data["per_page"], 0)
      @total = integer(data["total"], 0)
      @total_pages = integer(data["total_pages"], 0)
      freeze
    end

    def has_more? # rubocop:disable Naming/PredicatePrefix
      @page < @total_pages
    end

    private

    def integer(value, default)
      Internal::PHP.numeric?(value) ? Internal::PHP.numeric_to_i(value) : default
    end
  end
end
