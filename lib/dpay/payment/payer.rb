# frozen_string_literal: true

module DPay
  class Payer
    EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

    attr_reader :email, :first_name, :last_name

    def self.create
      new
    end

    def with_email(email)
      raise InvalidArgumentError, %(Invalid email "#{email}") unless email.is_a?(String) && EMAIL.match?(email)

      @email = email
      self
    end

    def with_name(first_name, last_name)
      @first_name = first_name
      @last_name = last_name
      self
    end
  end
end
