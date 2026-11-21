# frozen_string_literal: true

RSpec.describe DPay::RegisterPaymentRequest do
  let(:urls) { DPay::ReturnUrls.new("https://shop.test/ok", "https://shop.test/fail", "https://shop.test/ipn") }

  def request
    described_class.create(DPay::Money.pln(2999), DPay::TransactionType::TRANSFERS, urls)
  end

  it "builds the minimal body in protocol order" do
    body = request.to_body("test_service")

    expect(body.keys).to eq(%w[service value transactionType url_success url_fail url_ipn])
    expect(body["value"]).to eq("29.99")
    expect(body["transactionType"]).to eq("transfers")
  end

  it "appends optional fields in protocol order" do
    body = request
           .with_description("Zamowienie #1234")
           .with_custom("order-1234")
           .with_payer(DPay::Payer.create.with_email("jan@example.com").with_name("Jan", "Kowalski"))
           .with_accept_tos(true)
           .with_channel("86")
           .to_body("test_service")

    expect(body.keys).to eq(
      %w[service value transactionType url_success url_fail url_ipn
         description custom email client_name client_surname accept_tos channel]
    )
  end

  it "serializes method toggles as integers" do
    body = request.with_credit_card(true).with_paysafecard(false).with_blik(true).to_body("test_service")

    expect(body["creditcard"]).to eq(1)
    expect(body["paysafecard"]).to eq(0)
    expect(body["blik"]).to eq(1)
  end

  it "validates the transaction type" do
    expect { described_class.create(DPay::Money.pln(100), "cash", urls) }
      .to raise_error(DPay::InvalidArgumentError)
  end

  it "validates BLIK inputs and mutual exclusions" do
    expect { request.with_blik_code("12345", "UA", "1.2.3.4") }.to raise_error(DPay::InvalidArgumentError)
    expect { request.with_blik_code("123456", "UA", "1.2.3.4").with_blik_alias("a-1", "UA", "1.2.3.4") }
      .to raise_error(DPay::InvalidArgumentError, /cannot be combined/)
    expect { request.with_partner_platform("shopify") }.to raise_error(DPay::InvalidArgumentError)
  end

  it "rejects conflicting card recurring configuration" do
    registration = double(to_h: { "label" => "m" })

    expect { request.with_card_recurring_alias("alias").with_card_recurring(registration) }
      .to raise_error(DPay::InvalidArgumentError, /cannot be combined/)
  end

  it "allows efaktura only for transfers" do
    card = described_class.create(DPay::Money.pln(100), DPay::TransactionType::CARD_AUTH, urls)

    expect { card.with_efaktura }.to raise_error(DPay::InvalidArgumentError, /transfers/)
    expect(request.with_efaktura.to_body("test_service")["efaktura"]).to be(true)
  end

  it "serializes nested structures" do
    position = DPay::PayoutPosition.new("PL61109010140000071219812874", "t", DPay::Money.pln(1050))
    body = request.with_payout(DPay::PayoutInstruction.create([position])).to_body("test_service")

    expect(body["payout"]).to eq(
      { "fee_mode" => "net",
        "positions" => [{ "iban" => "PL61109010140000071219812874", "title" => "t", "amount" => 10.5 }] }
    )
  end

  describe "currency" do
    let(:urls) { DPay::ReturnUrls.new("https://shop.example/ok", "https://shop.example/fail", "https://shop.example/ipn") }

    def create(amount, type = DPay::TransactionType::TRANSFERS)
      described_class.create(amount, type, urls)
    end

    it "sends the currency of a non-PLN amount as currency_code" do
      body = create(DPay::Money.of(49_900, DPay::Currency::CZK)).to_body("MyShop")

      expect(body["value"]).to eq("499.00")
      expect(body["currency_code"]).to eq("CZK")
      expect(body.keys).to eq(%w[service value transactionType url_success url_fail url_ipn currency_code])
      expect(create(DPay::Money.of(100, DPay::Currency::RON)).to_body("S")["currency_code"]).to eq("RON")
    end

    it "sends no currency for a PLN amount unless asked to" do
      expect(create(DPay::Money.pln(1000)).to_body("MyShop")).not_to have_key("currency_code")
      expect(create(DPay::Money.pln(1000)).with_currency_code(DPay::Currency::PLN).to_body("MyShop")["currency_code"])
        .to eq("PLN")
    end

    it "keeps currency_code between phone_number and partner_platform" do
      body = create(DPay::Money.of(500, DPay::Currency::EUR)).with_partner_platform("SHOP1").to_body("S")

      expect(body.keys.last(2)).to eq(%w[currency_code partner_platform])
    end

    it "requires the currency code to match the amount" do
      expect { create(DPay::Money.pln(500)).with_currency_code(DPay::Currency::EUR) }
        .to raise_error(DPay::InvalidArgumentError,
                        /\ACurrency code "EUR" does not match the amount currency "PLN"/)
      expect do
        create(DPay::Money.pln(500), DPay::TransactionType::MB_WAY_DIRECT)
          .with_phone_number("+351912345678", DPay::Currency::EUR)
      end.to raise_error(DPay::InvalidArgumentError, /does not match the amount currency/)
      expect { create(DPay::Money.pln(500)).with_currency_code("eur") }
        .to raise_error(DPay::InvalidArgumentError, 'Invalid currency code "eur"')
    end

    it "requires a phone number of 9-15 characters" do
      %w[+3519123 +351912345678901].each do |phone|
        expect { create(DPay::Money.of(500, "EUR")).with_phone_number(phone, "EUR") }
          .to raise_error(DPay::InvalidArgumentError, "Phone number must be 9-15 characters")
      end
      expect(create(DPay::Money.of(500, "EUR")).with_phone_number("+35191234", "EUR").to_body("S")["phone_number"])
        .to eq("+35191234")
    end
  end

  describe "direct channels and MB WAY" do
    let(:urls) { DPay::ReturnUrls.new("https://shop.example/ok", "https://shop.example/fail", "https://shop.example/ipn") }
    let(:payer) { DPay::Payer.create.with_email("client@example.com").with_name("Joao", "Silva") }

    def device_info(java_enabled)
      info = DPay::DeviceInfo.create(
        browser_accept_header: "text/html", browser_language: "pt-PT", browser_color_depth: 24,
        browser_screen_height: 1200, browser_screen_width: 1920, browser_tz: -60, browser_user_agent: "Mozilla/5.0",
        system_family: "Win32", geo_localization: "38.72,-9.14", device_id: "device-1", application_name: "Netscape"
      )
      java_enabled.nil? ? info : info.with_browser_java_enabled(java_enabled)
    end

    def mb_way
      described_class.create(DPay::Money.of(500, DPay::Currency::EUR), DPay::TransactionType::MB_WAY_DIRECT, urls)
                     .with_phone_number("+351912345678", DPay::Currency::EUR)
    end

    def transfer
      described_class.create(DPay::Money.pln(1000), DPay::TransactionType::TRANSFERS, urls)
    end

    it "builds a valid MB WAY registration" do
      body = mb_way.with_channel("373").with_payer(payer).with_accept_tos(true).with_device_info(device_info(false))
                   .to_body("MyShop")

      expect(body["phone_number"]).to eq("+351912345678")
      expect(body["currency_code"]).to eq("EUR")
      expect(body["channel"]).to eq("373")
      expect(body["device_info"]["browserJavaEnabled"]).to eq("false")
      expect(device_info(nil).browser_java_enabled).to be_nil
      expect(device_info(false).browser_java_enabled).to be(false)
    end

    it "requires a channel and device info with browserJavaEnabled for MB WAY" do
      expect { mb_way.with_payer(payer).with_accept_tos(true).with_device_info(device_info(true)).to_body("S") }
        .to raise_error(DPay::InvalidArgumentError, /requires a channel/)
      expect { mb_way.with_channel("373").with_payer(payer).with_accept_tos(true).to_body("S") }
        .to raise_error(DPay::InvalidArgumentError, /browserJavaEnabled/)
      expect do
        mb_way.with_channel("373").with_payer(payer).with_accept_tos(true).with_device_info(device_info(nil))
              .to_body("S")
      end.to raise_error(DPay::InvalidArgumentError, /browserJavaEnabled/)
    end

    it "requires the payer and the terms acceptance for a direct channel" do
      expect { transfer.with_channel("24900005").with_accept_tos(true).to_body("S") }
        .to raise_error(DPay::InvalidArgumentError, /email, first name and last name/)
      expect do
        transfer.with_channel("24900005").with_payer(DPay::Payer.create.with_email("client@example.com"))
                .with_accept_tos(true).to_body("S")
      end.to raise_error(DPay::InvalidArgumentError, /first name/)
      expect do
        transfer.with_channel("24900005").with_payer(DPay::Payer.create.with_name("Jan", "Kowalski"))
                .with_accept_tos(true).to_body("S")
      end.to raise_error(DPay::InvalidArgumentError, /email/)
      expect { transfer.with_channel("24900005").with_payer(payer).to_body("S") }
        .to raise_error(DPay::InvalidArgumentError, /with_accept_tos/)
    end

    it "accepts declined terms, which the API still counts as sent" do
      body = transfer.with_channel("24900005").with_payer(payer).with_accept_tos(false).to_body("S")

      expect(body["accept_tos"]).to be(false)
    end

    it "rejects the channels the API refuses as direct channels" do
      %w[tester paypal installment paysafecard].each do |channel|
        expect { transfer.with_channel(channel) }
          .to raise_error(DPay::InvalidArgumentError,
                          %(Channel "#{channel}" cannot be used as a direct payment channel))
      end
    end

    it "sends an empty channel as before 0.3.0 and treats it as no channel" do
      expect(transfer.with_channel("").to_body("S")["channel"]).to eq("")
      expect do
        mb_way.with_channel("").with_payer(payer).with_accept_tos(true).with_device_info(device_info(true)).to_body("S")
      end.to raise_error(DPay::InvalidArgumentError, /requires a channel/)
    end
  end

  it "accepts an alias IPN URL of at most 500 characters" do
    url = "https://shop.example/#{"a" * 479}"

    expect(request.with_alias_ipn_url(url).to_body("S")["alias_ipn_url"]).to eq(url)
    expect { request.with_alias_ipn_url("#{url}a") }.to raise_error(DPay::InvalidArgumentError, /alias IPN URL/)
  end

  it "rejects efaktura combined with BLIK aliases, recurring payments or card aliases" do
    registration = DPay::RecurringRegistration.create("Abonament", DPay::RecurringRegistration::MODEL_O,
                                                      "https://shop.example/terms")
    {
      "blik_code" => ->(req) { req.with_blik_code("777123", "UA", "1.2.3.4") },
      "blik_alias" => ->(req) { req.with_blik_alias("DPAY.UID.1.a", "UA", "1.2.3.4") },
      "register_blik_alias" => ->(req) { req.with_register_blik_alias(DPay::BlikAliasRegistration.new("Moj")) },
      "recurring_alias" => ->(req) { req.with_recurring_alias("SUB-0001") },
      "card_recurring_alias" => ->(req) { req.with_card_recurring_alias("c-1") }
    }.each do |field, configure|
      configured = configure.call(request.with_efaktura)

      expect { configured.to_body("S") }
        .to raise_error(DPay::InvalidArgumentError, "efaktura cannot be combined with #{field}")
    end
    with_registration = request.with_efaktura.with_blik_code("777123", "UA", "1.2.3.4")
                               .with_recurring_registration(registration)
    expect { with_registration.to_body("S") }.to raise_error(DPay::InvalidArgumentError, /efaktura cannot be combined/)
  end
end
