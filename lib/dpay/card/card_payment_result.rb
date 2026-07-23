# frozen_string_literal: true

module DPay
  class CardPaymentResult
    attr_reader :redirect_type, :redirect_text, :dcc_offer, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      message = data["message"].is_a?(Hash) ? data["message"] : {}

      @redirect_type = message["redirectType"].is_a?(String) ? message["redirectType"] : nil
      text = message["redirectText"]
      @redirect_text = text.is_a?(String) && !text.empty? ? text : nil
      @dcc_offer = message["dccOffer"].is_a?(Hash) ? DccOffer.from_api(message["dccOffer"]) : nil
      freeze
    end

    def success?
      @redirect_type == RedirectType::SUCCESS
    end

    def three_ds_form?
      @redirect_type == RedirectType::FORM
    end

    def requires_redirect?
      @redirect_type == RedirectType::URL
    end

    def dcc_offer?
      @redirect_type == RedirectType::DCC_OFFER
    end

    def three_ds_form_html
      three_ds_form? ? decode : nil
    end

    def redirect_url
      requires_redirect? ? decode : nil
    end

    private

    def decode
      text = @redirect_text
      return nil if text.nil?

      decoded = text.unpack1("m0")
      decoded.is_a?(String) ? decoded : nil
    rescue ArgumentError
      nil
    end
  end
end
