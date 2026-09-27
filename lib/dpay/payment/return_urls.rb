# frozen_string_literal: true

module DPay
  class ReturnUrls
    HTTP_URL = %r{\Ahttps?://[^\s]+\z}

    attr_reader :success, :fail, :ipn

    # ipn is optional: without it no IPN is sent and "url_ipn" is left out (the outcome comes as a webhook).
    def initialize(success, fail, ipn = nil)
      { "success" => success, "fail" => fail, "ipn" => ipn }.each do |name, url|
        next if name == "ipn" && url.nil?
        raise InvalidArgumentError, %(Invalid #{name} URL "#{url}") unless url.is_a?(String) && HTTP_URL.match?(url)
      end

      @success = success
      @fail = fail
      @ipn = ipn
      freeze
    end
  end
end
