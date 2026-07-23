# frozen_string_literal: true

module DPay
  class ReturnUrls
    HTTP_URL = %r{\Ahttps?://[^\s]+\z}

    attr_reader :success, :fail, :ipn

    def initialize(success, fail, ipn)
      { "success" => success, "fail" => fail, "ipn" => ipn }.each do |name, url|
        raise InvalidArgumentError, %(Invalid #{name} URL "#{url}") unless url.is_a?(String) && HTTP_URL.match?(url)
      end

      @success = success
      @fail = fail
      @ipn = ipn
      freeze
    end
  end
end
