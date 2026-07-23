# frozen_string_literal: true

module DPay
  module TransactionStatus
    PAID = "paid"
    CREATED = "created"
    PROCESSING = "processing"
    EXPIRED = "expired"
    CAPTURED = "captured"

    ALL = [PAID, CREATED, PROCESSING, EXPIRED, CAPTURED].freeze

    def self.valid?(value)
      ALL.include?(value)
    end

    def self.assert_valid(value)
      raise InvalidArgumentError, %(Invalid transaction status "#{value}") unless valid?(value)
    end
  end
end
