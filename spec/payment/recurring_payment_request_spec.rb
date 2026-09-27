# frozen_string_literal: true

require "dpay/testing"

# Registration and charges of recurring payments, optional IPN, webhook target and reference (SDK 0.2.0).
RSpec.describe "DPay recurring payment requests" do
  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) do
    DPay::Config.new(service: "sdk-test-service", secret_hash: "sdk-test-hash-0001", http_client: transport)
  end
  let(:service) { DPay::PaymentService.new(DPay::Internal::ApiRequestor.new(config, transport)) }
  let(:registration) do
    DPay::RecurringRegistration.create("Abonament", DPay::RecurringRegistration::MODEL_O, "https://shop.example/terms")
                               .with_alias("SUB-0001")
  end

  def urls(ipn = "https://shop.example/ipn")
    DPay::ReturnUrls.new("https://shop.example/ok", "https://shop.example/fail", ipn)
  end

  def request(minor, ipn = "https://shop.example/ipn", type = DPay::TransactionType::TRANSFERS)
    DPay::RegisterPaymentRequest.create(DPay::Money.pln(minor), type, urls(ipn))
  end

  it "registers with the object and the BLIK code, without IPN" do
    transport.queue_json(200, { "error" => false, "msg" => "Internal processing", "status" => true,
                                "transactionId" => "TX-REG",
                                "additionalInfo" => { "recurring_registration" => { "alias" => "SUB-0001",
                                                                                    "methods" => ["blik"] } } })

    payment = service.register(
      request(0, nil).with_blik_code("777123", "Mozilla/5.0", "203.0.113.42").with_recurring_registration(registration)
    )

    body = transport.last_request_body
    expect(body).not_to have_key("url_ipn")
    expect(body).not_to have_key("register_blik_recurring_alias")
    expect(body["recurring_registration"]).to eq(
      { "label" => "Abonament", "alias" => "SUB-0001", "model" => "O", "terms_url" => "https://shop.example/terms" }
    )
    expect(body["blik_code"]).to eq("777123")
    # Without IPN: empty last segment, no alias in the registration checksum
    expect(body["checksum"]).to eq("b5dbca75c515bc76094dba4d2853493bf050bfcd47c25bc899361884080f3544")
    expect(payment.recurring_alias).to eq("SUB-0001")
    expect(payment.recurring_methods).to eq(["blik"])
  end

  it "binds the alias of a charge in the checksum" do
    transport.queue_json(200, { "error" => false, "msg" => "Internal processing", "status" => true,
                                "transactionId" => "TX-CHG" })

    service.register(request(4999).with_recurring_alias("SUB-0001").with_description("Abonament 10/2026"))

    body = transport.last_request_body
    expect(body["recurring_alias"]).to eq("SUB-0001")
    expect(body).not_to have_key("user_ip")
    # sha256(service|hash|value|url_success|url_fail|url_ipn|recurring_alias)
    expect(body["checksum"]).to eq("96b80b9bceab99b92228bc8bd793b432b1594484ac45dc2715d2ebd542f3b2aa")
  end

  it "keeps the empty IPN segment in the checksum of a charge without IPN" do
    transport.queue_json(200, { "error" => false, "msg" => "Internal processing", "status" => true,
                                "transactionId" => "TX-CHG" })

    service.register(
      request(4999, nil).with_recurring_alias("SUB-0001").with_client_context("Mozilla/5.0", "203.0.113.42")
    )

    body = transport.last_request_body
    expect(body["user_agent"]).to eq("Mozilla/5.0")
    expect(body["user_ip"]).to eq("203.0.113.42")
    expect(body["checksum"]).to eq("b521018f255bab928187d73802d2dd79c48dda4c6574d1f57e7395cda70a8e5c")
  end

  it "keeps the webhook and the reference out of the checksum" do
    transport.queue_json(200, { "error" => false, "msg" => "https://secure.dpay.pl/pay/TX", "status" => true,
                                "transactionId" => "TX" })

    service.register(
      request(1000)
        .with_webhook(DPay::WebhookTarget.create("https://shop.example/webhooks", %w[payment.succeeded payment.failed]))
        .with_reference("  order-1234 ")
    )

    body = transport.last_request_body
    expect(body["webhook"]).to eq(
      { "url" => "https://shop.example/webhooks", "events" => %w[payment.succeeded payment.failed] }
    )
    expect(body["reference"]).to eq("order-1234")
    expect(body.keys.last(3)).to eq(%w[webhook reference checksum])
    expect(body["checksum"]).to eq("0a163ad60b5d2fd09eacce0032cc4d584e707c457051d2c4365b320dc340bc28")
  end

  it "rejects a registration without the BLIK code before sending" do
    expect { request(0).with_recurring_registration(registration).to_body("sdk-test-service") }
      .to raise_error(DPay::InvalidArgumentError, /BLIK code/)
  end

  it "validates the registration terms when the body is built" do
    invalid = DPay::RecurringRegistration.create("Abonament", "A", "https://shop.example/terms")
    built = request(0).with_blik_code("777123", "UA", "10.0.0.1").with_recurring_registration(invalid)

    expect { built.to_body("sdk-test-service") }
      .to raise_error(DPay::InvalidArgumentError, "frequency is required in recurring model A")
  end

  it "rejects a charge with a BLIK code, a zero amount or another transaction type" do
    [
      request(4999).with_blik_code("777123", "Mozilla/5.0", "203.0.113.42").with_recurring_alias("SUB-0001"),
      request(0).with_recurring_alias("SUB-0001"),
      request(4999, "https://shop.example/ipn", DPay::TransactionType::CARD_RECURRING).with_recurring_alias("SUB-0001")
    ].each do |invalid|
      expect { invalid.to_body("sdk-test-service") }.to raise_error(DPay::InvalidArgumentError)
    end
  end

  it "rejects the fields excluded by a recurring payment" do
    blik = request(0).with_blik_code("777123", "UA", "10.0.0.1").with_recurring_registration(registration)

    expect { blik.with_channel("86").to_body("s") }
      .to raise_error(DPay::InvalidArgumentError, "channel cannot be combined with a recurring payment")
    expect { request(4999).with_recurring_alias("SUB-0001").with_card_recurring_alias("c-1").to_body("s") }
      .to raise_error(DPay::InvalidArgumentError, "card_recurring_alias cannot be combined with a recurring payment")
    expect { request(4999).with_recurring_alias("SUB-0001").with_blik_alias("a-1", "UA", "10.0.0.1") }
      .to raise_error(DPay::InvalidArgumentError, /recurring payments/)
    expect do
      request(0).with_blik_code("777123", "UA", "10.0.0.1").with_recurring_registration(registration)
                .with_recurring_alias("SUB-0001").to_body("s")
    end.to raise_error(DPay::InvalidArgumentError, "recurring_registration cannot be combined with recurring_alias")
  end

  it "validates the alias, the client IP and the reference" do
    expect { request(4999).with_recurring_alias("") }.to raise_error(DPay::InvalidArgumentError)
    expect { request(4999).with_recurring_alias("a" * 129) }.to raise_error(DPay::InvalidArgumentError)
    expect { request(4999).with_client_context("UA", "999.1.1.1") }
      .to raise_error(DPay::InvalidArgumentError, 'Invalid user IP "999.1.1.1"')
    expect { request(4999).with_client_context("UA", "fe80::1%eth0") }.to raise_error(DPay::InvalidArgumentError)
    expect(request(4999).with_client_context("UA", "2001:db8::1").to_body("s")["user_ip"]).to eq("2001:db8::1")
    ["", "   ", "x" * 65, "order\n1"].each do |reference|
      expect { request(1000).with_reference(reference) }.to raise_error(DPay::InvalidArgumentError)
    end
  end

  it "accepts only payment events in the webhook of a registration" do
    expect do
      request(1000).with_webhook(DPay::WebhookTarget.create("https://shop.example/webhooks", ["payout.paid"]))
    end.to raise_error(DPay::InvalidArgumentError, /payment registration/)
  end

  it "requires an https webhook URL" do
    expect { DPay::WebhookTarget.create("http://shop.example/webhooks") }.to raise_error(DPay::InvalidArgumentError)
  end
end
