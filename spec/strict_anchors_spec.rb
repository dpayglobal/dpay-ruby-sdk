# frozen_string_literal: true

require "dpay/testing"

# Every validation pattern must match the whole string: \A...\z, never the line anchors ^/$ (in Ruby they would
# accept "x\n123456"), so a trailing "\n" is rejected the same way the PHP SDK rejects it.
RSpec.describe "Strict pattern anchors" do
  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:api) do
    DPay::Internal::ApiRequestor.new(
      DPay::Config.new(service: "MyShop", secret_hash: "secret123", http_client: transport), transport
    )
  end
  let(:request) do
    DPay::RegisterPaymentRequest.create(
      DPay::Money.pln(1000), DPay::TransactionType::TRANSFERS,
      DPay::ReturnUrls.new("https://shop.example/ok", "https://shop.example/fail", "https://shop.example/ipn")
    )
  end
  let(:recurring) do
    DPay::RecurringRegistration.create("Abonament", DPay::RecurringRegistration::MODEL_O, "https://shop.example/terms")
  end

  it "rejects a trailing newline in every validated argument" do
    {
      -> { api.send_raw("POST", DPay::Internal::BaseUrls::PANEL, "/x", {}, { "X-Id\n" => "1" }) } =>
        %(Invalid request header "X-Id\n"),
      -> { DPay::RefundService.new(api).create("30D9493D-1D73-3FBD-A5D4-633723CC7A68", nil, nil, nil, "RET\n") } =>
        "Refund message ID must be non-empty printable ASCII",
      -> { DPay::CardData.new("4111111111111111\n", "123", "12/30") } => "Card number must be 12-19 digits",
      -> { DPay::CardData.new("4111111111111111", "123\n", "12/30") } => "CVV must be 3-4 digits",
      -> { DPay::CardData.new("4111111111111111", "123", "12/30\n") } => "Expiry must be in MM/YY format",
      -> { DPay::CardRecurringRegistration.create("Abonament").with_init_date("2026-12-01\n") } =>
        %(Date "2026-12-01\n" must be in YYYY-MM-DD format),
      -> { DPay::Money.from_decimal("10.00\n", DPay::Currency::PLN) } => %(Invalid money amount "10.00\n"),
      -> { DPay::InvoiceDetails.create.with_payment_due_date("2026-12-01\n") } =>
        "Payment due date must be in YYYY-MM-DD format",
      -> { request.with_partner_platform("SHOPER\n") } => "Partner platform must match ^[A-Z0-9]{1,64}$",
      -> { request.with_blik_code("123456\n", "Mozilla/5.0", "203.0.113.10") } => "BLIK code must be exactly 6 digits",
      -> { recurring.with_frequency("1M\n") } => %(Invalid recurring frequency "1M\n"),
      -> { recurring.with_init_date("2026-12-01\n") } => %(Date "2026-12-01\n" must be in YYYY-MM-DD format),
      -> { DPay::EventService.new(api).list({ "starting_after" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6y\n" }) } =>
        "starting_after must be an event id (evt_...)"
    }.each do |call, message|
      expect { call.call }.to raise_error(DPay::InvalidArgumentError, message)
    end
    expect(transport.requests).to be_empty
  end

  it "rejects a value with a valid line before or after it, which line anchors would accept" do
    expect { DPay::CardData.new("x\n4111111111111111", "123", "12/30") }
      .to raise_error(DPay::InvalidArgumentError, "Card number must be 12-19 digits")
    expect { request.with_blik_code("x\n123456", "Mozilla/5.0", "203.0.113.10") }
      .to raise_error(DPay::InvalidArgumentError, "BLIK code must be exactly 6 digits")
    expect(DPay::Currency.valid?("PLN\nEUR")).to be(false)
  end

  it "does not read values with a trailing newline" do
    transaction = DPay::Transaction.from_api({ "transaction" => { "minimal_fee" => "30\n", "permanent_fee" => "30" } })

    expect(DPay::Currency.valid?("PLN\n")).to be(false)
    expect(DPay::Money.try_from_api_number("10.00\n", DPay::Currency::PLN)).to be_nil
    expect(transaction.minimal_fee).to be_nil
    expect(transaction.permanent_fee).to eq(30)
  end

  it "rejects a webhook-timestamp header with a trailing newline" do
    headers = { "webhook-id" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6y", "webhook-timestamp" => "1790503500\n",
                "webhook-signature" => "v1,x" }

    secret = "whsec_ZHBheS1zZGstc3ludGhldGljLXRlc3Qtc2VjcmV0ISE="

    expect do
      DPay::WebhookVerifier.verify("{}", headers, secret, 300, 1_790_503_500)
    end.to raise_error(DPay::SignatureVerificationError, "Invalid webhook-timestamp header")
  end
end
