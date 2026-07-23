# frozen_string_literal: true

module DPay
  class RegisterPaymentRequest
    BLIK_CODE = /\A\d{6}\z/
    PARTNER_PLATFORM = /\A[A-Z0-9]{1,64}\z/
    HTTP_URL = %r{\Ahttps?://[^\s]+\z}
    TOGGLES = { "creditcard" => :@credit_card, "paysafecard" => :@paysafecard, "blik" => :@blik,
                "installment" => :@installment, "paypal" => :@paypal, "nobanks" => :@no_banks }.freeze

    attr_reader :amount

    def self.create(amount, transaction_type, urls)
      new(amount, transaction_type, urls)
    end

    def initialize(amount, transaction_type, urls)
      TransactionType.assert_valid(transaction_type)

      @amount = amount
      @transaction_type = transaction_type
      @urls = urls
      @optional = {}
    end

    def with_description(description)
      set("description", description)
    end

    def with_custom(custom)
      set("custom", custom)
    end

    def with_payer(payer)
      @payer = payer
      self
    end

    def with_accept_tos(accept_tos)
      set("accept_tos", accept_tos)
    end

    def with_channel(channel)
      set("channel", channel)
    end

    def with_credit_card(enabled)
      @credit_card = enabled
      self
    end

    def with_paysafecard(enabled)
      @paysafecard = enabled
      self
    end

    def with_blik(enabled)
      @blik = enabled
      self
    end

    def with_installment(enabled)
      @installment = enabled
      self
    end

    def with_paypal(enabled)
      @paypal = enabled
      self
    end

    def with_no_banks(disabled)
      @no_banks = disabled
      self
    end

    def with_phone_number(phone_number, currency_code)
      Currency.assert_valid(currency_code)
      set("phone_number", phone_number)
      set("currency_code", currency_code)
    end

    def with_currency_code(currency_code)
      Currency.assert_valid(currency_code)
      set("currency_code", currency_code)
    end

    def with_partner_platform(partner_platform)
      unless partner_platform.is_a?(String) && PARTNER_PLATFORM.match?(partner_platform)
        raise InvalidArgumentError, "Partner platform must match ^[A-Z0-9]{1,64}$"
      end

      set("partner_platform", partner_platform)
    end

    def with_blik_code(blik_code, user_agent, user_ip)
      raise InvalidArgumentError, "BLIK code must be exactly 6 digits" unless BLIK_CODE.match?(blik_code.to_s)
      raise InvalidArgumentError, "blik_code cannot be combined with blik_alias" if @optional.key?("blik_alias")

      set("blik_code", blik_code)
      set("user_agent", user_agent)
      set("user_ip", user_ip)
    end

    def with_blik_alias(alias_value, user_agent, user_ip)
      if @optional.key?("blik_code") || @optional.key?("register_blik_alias") ||
         @optional.key?("register_blik_recurring_alias")
        raise InvalidArgumentError, "blik_alias cannot be combined with blik_code or alias registration"
      end

      set("blik_alias", alias_value)
      set("user_agent", user_agent)
      set("user_ip", user_ip)
    end

    def with_register_blik_alias(registration)
      if @optional.key?("blik_alias")
        raise InvalidArgumentError, "register_blik_alias cannot be combined with blik_alias"
      end

      set("register_blik_alias", registration.to_h)
    end

    def with_register_blik_recurring_alias(registration)
      if @optional.key?("blik_alias")
        raise InvalidArgumentError, "register_blik_recurring_alias cannot be combined with blik_alias"
      end

      set("register_blik_recurring_alias", registration.to_h)
    end

    def with_alias_ipn_url(url)
      raise InvalidArgumentError, %(Invalid alias IPN URL "#{url}") unless url.is_a?(String) && HTTP_URL.match?(url)

      set("alias_ipn_url", url)
    end

    def with_no_delay(no_delay)
      set("no_delay", no_delay)
    end

    def with_card_recurring(registration)
      if @optional.key?("card_recurring_alias")
        raise InvalidArgumentError, "register_card_recurring cannot be combined with card_recurring_alias"
      end

      set("register_card_recurring", registration.to_h)
    end

    def with_card_recurring_alias(alias_value)
      if @optional.key?("register_card_recurring")
        raise InvalidArgumentError, "card_recurring_alias cannot be combined with register_card_recurring"
      end

      set("card_recurring_alias", alias_value)
    end

    def with_authorize_only(authorize_only)
      set("authorize_only", authorize_only)
    end

    def with_card_recurring_operation(operation)
      CardRecurringOperation.assert_valid(operation)
      set("card_recurring_operation", operation)
    end

    def with_payout(payout)
      set("payout", payout.to_h)
    end

    def with_billing_address(billing_address)
      set("billing_address", billing_address)
    end

    def with_shipping_address(shipping_address)
      set("shipping_address", shipping_address)
    end

    def with_device_info(device_info)
      set("device_info", device_info.to_h)
    end

    def with_products(products)
      set("products", products)
    end

    def with_efaktura(invoice = nil)
      unless @transaction_type == TransactionType::TRANSFERS
        raise InvalidArgumentError, %(efaktura is allowed only for transactionType "transfers")
      end

      set("efaktura", true)
      invoice.nil? ? self : set("invoice", invoice.to_h)
    end

    def to_body(service)
      body = {
        "service" => service,
        "value" => @amount.to_decimal,
        "transactionType" => @transaction_type,
        "url_success" => @urls.success,
        "url_fail" => @urls.fail,
        "url_ipn" => @urls.ipn
      }

      append(body, "description")
      append(body, "custom")
      append_payer(body)
      append(body, "accept_tos")
      append(body, "channel")
      append_toggles(body)
      %w[phone_number currency_code partner_platform user_agent user_ip blik_code blik_alias register_blik_alias
         register_blik_recurring_alias alias_ipn_url no_delay register_card_recurring card_recurring_alias
         authorize_only card_recurring_operation payout billing_address shipping_address device_info products
         efaktura invoice].each { |key| append(body, key) }

      body
    end

    private

    def set(key, value)
      @optional[key] = value
      self
    end

    def append(body, key)
      body[key] = @optional[key] if @optional.key?(key)
    end

    def append_payer(body)
      return if @payer.nil?

      body["email"] = @payer.email unless @payer.email.nil?
      body["client_name"] = @payer.first_name unless @payer.first_name.nil?
      body["client_surname"] = @payer.last_name unless @payer.last_name.nil?
    end

    def append_toggles(body)
      TOGGLES.each do |key, variable|
        flag = instance_variable_defined?(variable) ? instance_variable_get(variable) : nil
        body[key] = flag ? 1 : 0 unless flag.nil?
      end
    end
  end
end
