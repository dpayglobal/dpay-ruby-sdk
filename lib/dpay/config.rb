# frozen_string_literal: true

module DPay
  class Config
    DEFAULT_TIMEOUT = 30

    attr_reader :service, :secret_hash, :timeout, :http_client, :base_urls

    def initialize(service:, secret_hash:, timeout: DEFAULT_TIMEOUT, http_client: nil, base_urls: nil)
      @service = non_empty_string(service, "service")
      @secret_hash = non_empty_string(secret_hash, "secret_hash")
      @timeout = positive_integer(timeout)
      @http_client = transport(http_client)
      @base_urls = Internal::BaseUrls.new(base_urls || {})
      freeze
    end

    private

    def non_empty_string(value, name)
      raise InvalidArgumentError, "#{name} must be a non-empty String" unless value.is_a?(String) && !value.empty?

      value
    end

    def positive_integer(value)
      raise InvalidArgumentError, "timeout must be an Integer >= 1" unless value.is_a?(Integer) && value >= 1

      value
    end

    def transport(value)
      return nil if value.nil?
      raise InvalidArgumentError, "http_client must respond to #request" unless value.respond_to?(:request)

      value
    end
  end
end
