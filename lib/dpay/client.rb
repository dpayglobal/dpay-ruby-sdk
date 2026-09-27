# frozen_string_literal: true

module DPay
  class Client
    VERSION = DPay::VERSION

    attr_reader :config, :payments, :refunds, :banks, :blik, :cards, :payouts, :recurring, :events

    def initialize(service:, secret_hash:, timeout: Config::DEFAULT_TIMEOUT, http_client: nil, base_urls: nil)
      @config = Config.new(
        service: service, secret_hash: secret_hash, timeout: timeout,
        http_client: http_client, base_urls: base_urls
      )

      api = Internal::ApiRequestor.new(@config, @config.http_client || HTTP::NetHTTPClient.new(@config.timeout))

      @payments = PaymentService.new(api)
      @refunds = RefundService.new(api)
      @banks = BankService.new(api)
      @blik = BlikService.new(api)
      @cards = CardService.new(api)
      @payouts = PayoutService.new(api)
      @recurring = RecurringService.new(api)
      @events = EventService.new(api)
      freeze
    end
  end
end
