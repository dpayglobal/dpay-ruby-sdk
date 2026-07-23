# frozen_string_literal: true

module DPay
  module Internal
    class BaseUrls
      API_PAYMENTS = :api_payments
      PANEL = :panel
      GATEWAY = :gateway

      DEFAULTS = {
        API_PAYMENTS => "https://api-payments.dpay.pl",
        PANEL => "https://panel.dpay.pl",
        GATEWAY => "https://secure.dpay.pl"
      }.freeze

      def initialize(overrides = {})
        urls = DEFAULTS.dup

        overrides.each do |host, url|
          key = host.to_sym
          raise InvalidArgumentError, %(Unknown base URL key "#{host}") unless DEFAULTS.key?(key)

          urls[key] = url.to_s.sub(%r{/+\z}, "")
        end

        @urls = urls.freeze
        freeze
      end

      def resolve(host)
        key = host.to_sym
        raise InvalidArgumentError, %(Unknown API host "#{host}") unless @urls.key?(key)

        @urls[key]
      end
    end
  end
end
