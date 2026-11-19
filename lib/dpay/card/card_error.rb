# frozen_string_literal: true

module DPay
  # Card decline details: the "error" object of a declined card operation (HTTP 200, "success": false) and the
  # "cardError" object of a Payments API error (e.g. a declined charge on a saved card). Every field can be nil.
  class CardError
    # code: stable dpay reason, e.g. "payment_declined", "invalid_card", "card_already_registered".
    # decline_code: two-character card network response code (ISO 8583), e.g. "05", "51"; nil when not from an
    # authorisation. decline_message: English description of the decline code - localise from decline_code.
    attr_reader :code, :decline_code, :decline_message

    def self.from_api(data)
      new(string(data["code"]), string(data["declineCode"]), string(data["declineMessage"]))
    end

    def self.string(value)
      value.is_a?(String) || value.is_a?(Integer) ? value.to_s : nil
    end
    private_class_method :string

    def initialize(code, decline_code, decline_message)
      @code = code
      @decline_code = decline_code
      @decline_message = decline_message
      freeze
    end
  end
end
