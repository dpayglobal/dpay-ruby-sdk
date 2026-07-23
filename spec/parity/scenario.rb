# frozen_string_literal: true

require "dpay/testing"

module ParityScenario
  SERVICE = "test_service"
  SECRET = "sekret-hash-123"
  SUCCESS = { "success" => true, "message" => { "redirectType" => "SUCCESS" } }.freeze

  class Recorder < DPay::Testing::MockHttpClient
    def request(api_request)
      @requests << api_request
      @queued.empty? ? DPay::HTTP::Response.new(200, {}, "{}") : @queued.shift
    end
  end

  module_function

  def run
    recorder = Recorder.new
    dpay = DPay::Client.new(service: SERVICE, secret_hash: SECRET, http_client: recorder)
    device = device_info

    register_calls(dpay, recorder, device)
    panel_calls(dpay, recorder)
    blik_calls(dpay, recorder)
    card_calls(dpay, recorder, device)

    recorder.requests
  end

  def device_info
    DPay::DeviceInfo.create(
      browser_accept_header: "text/html", browser_language: "pl-PL", browser_color_depth: 24,
      browser_screen_height: 1080, browser_screen_width: 1920, browser_tz: -60,
      browser_user_agent: "Mozilla/5.0", system_family: "Windows", geo_localization: "52.2297,21.0122",
      device_id: "device-abc", application_name: "Sklep Testowy"
    ).with_browser_java_enabled(true)
  end

  def urls
    DPay::ReturnUrls.new("https://shop.test/ok", "https://shop.test/fail", "https://shop.test/ipn")
  end

  def register_calls(dpay, recorder, device)
    register_transfer_payment(dpay, recorder, device)
    register_blik_recurring_payment(dpay, recorder)
    register_card_recurring_payment(dpay, recorder)
  end

  def transfer_payout
    DPay::PayoutInstruction.create(
      [DPay::PayoutPosition.new("PL61109010140000071219812874", "Wypłata 1", DPay::Money.pln(1050))],
      DPay::PayoutFeeMode::GROSS
    )
  end

  def transfer_invoice
    DPay::InvoiceDetails.create
                        .with_payer_nip("1234563218")
                        .with_payer_name("Firma sp. z o.o.")
                        .with_invoice_number("FV/2026/07/1")
                        .with_payment_due_date("2026-08-15")
                        .with_vat_amount(DPay::Money.pln(560))
  end

  def register_transfer_payment(dpay, recorder, device)
    recorder.queue_json(200, { "transactionId" => "tx-1", "msg" => "https://secure.dpay.pl/pay/1" })
    dpay.payments.register(
      DPay::RegisterPaymentRequest.create(DPay::Money.pln(2999), DPay::TransactionType::TRANSFERS, urls)
        .with_description("Zamówienie #1234 / ĄĘŚŻ")
        .with_custom("order-1234")
        .with_payer(DPay::Payer.create.with_email("jan@example.com").with_name("Jan", "Kowalski"))
        .with_accept_tos(true)
        .with_channel("86")
        .with_credit_card(true)
        .with_paysafecard(false)
        .with_blik(true)
        .with_installment(false)
        .with_paypal(true)
        .with_no_banks(false)
        .with_phone_number("+48123456789", DPay::Currency::EUR)
        .with_partner_platform("SHOPIFY01")
        .with_alias_ipn_url("https://shop.test/alias-ipn")
        .with_no_delay(true)
        .with_authorize_only(false)
        .with_card_recurring_operation(DPay::CardRecurringOperation::CHARGE)
        .with_payout(transfer_payout)
        .with_billing_address({ "street" => "Testowa 1", "city" => "Warszawa" })
        .with_shipping_address({ "street" => "Inna 2" })
        .with_device_info(device)
        .with_products([{ "name" => "Produkt", "price" => 29.99 }])
        .with_efaktura(transfer_invoice)
    )
  end

  def register_blik_recurring_payment(dpay, recorder)
    recorder.queue_json(200, { "transactionId" => "tx-2", "msg" => "Transaction paid" })
    dpay.payments.register(
      DPay::RegisterPaymentRequest.create(DPay::Money.pln(1000), DPay::TransactionType::BLIK_RECURRING, urls)
        .with_blik_code("123456", "UA/1.0", "10.0.0.1")
        .with_register_blik_recurring_alias(
          DPay::BlikRecurringRegistration.create("Subskrypcja", "M", "12M")
            .with_value(DPay::Money.pln(4999))
            .with_limit_amt(100_000)
            .with_tot_limit_amt(500_000)
            .with_limit_amt_fixed(true)
            .with_expiration_date("2027-01-01")
            .with_init_date("2026-08-01")
        )
    )
  end

  def register_card_recurring_payment(dpay, recorder)
    recorder.queue_json(200, { "transactionId" => "tx-3", "msg" => "ok" })
    dpay.payments.register(
      DPay::RegisterPaymentRequest.create(
        DPay::Money.of(500, DPay::Currency::CZK), DPay::TransactionType::CARD_RECURRING, urls
      )
        .with_register_blik_alias(DPay::BlikAliasRegistration.new("Moj alias", "PAYID"))
        .with_card_recurring(
          DPay::CardRecurringRegistration.create("Mandat")
            .with_frequency("MONTHLY")
            .with_limit_amt(DPay::Money.pln(20_000))
            .with_tot_limit_amt(DPay::Money.pln(100_000))
            .with_limit_amt_fixed(false)
            .with_expiration_date("2028-12-31")
            .with_init_date("2026-09-01")
        )
    )
  end

  def panel_calls(dpay, recorder)
    recorder.queue_json(200, { "transaction" => { "id" => "tx-1", "value" => "29.99", "status" => "paid" } })
    dpay.payments.details("tx-1")

    recorder.queue_json(200, { "status" => "success", "refund" => true })
    dpay.refunds.create("tx-1")

    recorder.queue_json(200, { "status" => "success", "refund" => true })
    dpay.refunds.create("tx-1", DPay::Money.pln(1050), "reklamacja / zwrot")

    recorder.queue_json(200, { "refund" => true, "message" => "ok" })
    dpay.refunds.check_availability("tx-1", DPay::Money.pln(500))

    recorder.queue_json(200, [{ "id" => "1", "name" => "Bank", "on_from" => 0, "on_to" => 24 }])
    dpay.banks.all

    recorder.queue_json(200, [{ "id" => "1", "name" => "Bank" }])
    dpay.banks.for_service(1_784_700_000)

    recorder.queue_json(200, { "id" => 7, "state" => 1, "net" => 100.5 })
    dpay.payouts.details(4242)

    recorder.queue_json(200, { "id" => 7, "state" => 1 })
    dpay.payouts.details(4242, 1_784_700_000)
  end

  def blik_calls(dpay, recorder)
    recorder.queue_json(200, { "data" => { "alias_value" => "a-1", "alias_type" => "UID", "status" => "ACTIVE" } })
    dpay.blik.alias("a-1")

    recorder.queue_json(200, { "data" => {} })
    dpay.blik.unregister_alias("a-1", "PAYID", "user request")

    recorder.queue_json(200, { "data" => { "alias_value" => "a-1" } })
    dpay.blik.recurring_status("a-1")
  end

  def card_calls(dpay, recorder, device)
    recorder.queue_text(200, "-----BEGIN PUBLIC KEY-----\nAAA\n-----END PUBLIC KEY-----\n")
    dpay.cards.public_key

    recorder.queue_json(200, SUCCESS)
    dpay.cards.pay_otp(
      "tx 1/2",
      DPay::CardPaymentRequest.create(device)
        .with_email("jan@example.com")
        .with_channel_id(86)
        .with_card_holder("Jan", "Kowalski")
        .with_encrypted_card_data("BASE64DATA==")
        .with_three_ds_confirmed(true)
        .with_dcc_decision(DPay::DccDecision::ACCEPT)
    )

    recorder.queue_json(200, SUCCESS)
    dpay.cards.pre_auth("tx-1", DPay::CardPaymentRequest.create(device))

    recorder.queue_json(200, SUCCESS)
    dpay.cards.capture("tx-1", DPay::Money.pln(2999))

    recorder.queue_json(200, SUCCESS)
    dpay.cards.cancel("tx-1")

    recorder.queue_json(200, SUCCESS)
    dpay.cards.cancel("tx-1", DPay::Money.pln(100))

    recorder.queue_json(200, SUCCESS)
    dpay.cards.google_pay(
      "tx-1",
      DPay::GooglePayRequest.create("gp-token", device).with_email("a@b.pl").with_channel_id(90)
    )

    recorder.queue_json(200, SUCCESS)
    dpay.cards.apple_pay("tx-1", DPay::ApplePayRequest.init(device))

    recorder.queue_json(200, SUCCESS)
    dpay.cards.apple_pay("tx-1", DPay::ApplePayRequest.pay("ap-token", device).with_channel_id(91))
  end
end
