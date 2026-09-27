# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::CardService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "test_service", secret_hash: "sekret-hash-123", http_client: transport) }
  let(:device_info) do
    DPay::DeviceInfo.create(
      browser_accept_header: "text/html", browser_language: "pl-PL", browser_color_depth: 24,
      browser_screen_height: 1080, browser_screen_width: 1920, browser_tz: -60,
      browser_user_agent: "Mozilla/5.0", system_family: "Windows", geo_localization: "52.2297,21.0122",
      device_id: "device-1", application_name: "shop"
    )
  end

  it "fetches and trims the public key" do
    transport.queue_text(200, "-----BEGIN PUBLIC KEY-----\nMIIB\n-----END PUBLIC KEY-----\n")

    expect(service.public_key).to end_with("-----END PUBLIC KEY-----")
    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/cards/public-key")
  end

  it "pays with OTP and URL encodes the transaction id" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })

    result = service.pay_otp("tx 1/2", DPay::CardPaymentRequest.create(device_info).with_encrypted_card_data("enc"))

    expect(transport.last_request.url)
      .to eq("https://api-payments.dpay.pl/api/v1_0/cards/payment/tx%201%2F2/pay/card-otp")
    expect(transport.last_request_body["encryptedCardData"]).to eq("enc")
    expect(transport.last_request_body["deviceInfo"]["deviceID"]).to eq("device-1")
    expect(result).to be_success
  end

  it "captures with a float amount, the service and the operation checksum" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })

    service.capture("tx-1", DPay::Money.pln(2999))

    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/cards/payment/tx-1/capture")
    # sha256(capture|service|transaction_id|amount|hash)
    expect(transport.last_request.body).to eq(
      '{"service":"test_service","amount":29.99,' \
      '"checksum":"835182d11c896a412912bee6fb3baf0670051bde45ec7a1810c1748ec143bc27"}'
    )
  end

  it "signs a cancellation with an empty amount segment when there is no amount" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    service.cancel("tx-1")
    # sha256(cancellation|service|transaction_id||hash)
    expect(transport.last_request.body).to eq(
      '{"service":"test_service","checksum":"4f7656fc0700af82b74a940df21fd3075311bbb71dfd7266ed0895e5f459e368"}'
    )

    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    service.cancel("tx-1", DPay::Money.pln(100))
    expect(transport.last_request.body).to eq(
      '{"service":"test_service","amount":1,' \
      '"checksum":"1b0c0c82a4af6dec880d17a3f46ca0821ed36467afbdffb43ceafe5bc5f57eca"}'
    )
  end

  it "matches the shared capture vector" do
    vectors = ApiVectors.data
    recorder = DPay::Testing::MockHttpClient.new
    recorder.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    vector_config = DPay::Config.new(service: vectors["service"], secret_hash: vectors["secret_hash"])

    described_class.new(DPay::Internal::ApiRequestor.new(vector_config, recorder))
                   .capture(vectors["transaction_id"], DPay::Money.pln(5999))

    vector = vectors["operation"].find { |item| item["name"] == "capture_59_99" }
    expect(recorder.last_request_body["checksum"]).to eq(vector["checksum"])
  end

  it "sends a capture webhook target outside the checksum" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })

    service.capture(
      "tx-1", DPay::Money.pln(1500),
      DPay::WebhookTarget.create("https://shop.test/webhooks/captures", ["payment.captured"])
    )

    expect(transport.last_request.body).to eq(
      '{"service":"test_service","amount":15,' \
      '"webhook":{"url":"https://shop.test/webhooks/captures","events":["payment.captured"]},' \
      '"checksum":"424c5c1916bdffb3cfc28f8421973c9b7a68b2cddb4f6f0e6e237fc9f45ede5c"}'
    )
  end

  it "accepts only payment.captured in a capture webhook target" do
    target = DPay::WebhookTarget.create("https://shop.test/webhooks", ["refund.failed"])

    expect { service.capture("tx-1", DPay::Money.pln(100), target) }
      .to raise_error(DPay::InvalidArgumentError, /webhook object of a card capture/)
    expect(transport.requests).to be_empty
  end

  it "sends wallet payments" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    service.google_pay("tx-1", DPay::GooglePayRequest.create("gp-token", device_info))
    expect(transport.last_request_body["xPayType"]).to eq("GOOGLE_PAY")
    expect(transport.last_request_body["xPayToken"]).to eq("gp-token")

    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    service.apple_pay("tx-1", DPay::ApplePayRequest.init(device_info))
    expect(transport.last_request_body["xPayType"]).to eq("APPLE_PAY_INIT")
    expect(transport.last_request_body).not_to have_key("xPayToken")
  end

  it "raises CardPaymentError when success is not true on HTTP 200" do
    transport.queue_json(200, { "success" => false, "message" => "DCC_OFFER_EXPIRED" })

    expect { service.capture("tx-1", DPay::Money.pln(100)) }
      .to raise_error(DPay::CardPaymentError, "DCC_OFFER_EXPIRED")
  end

  it "validates the DCC decision" do
    expect { DPay::CardPaymentRequest.create(device_info).with_dcc_decision("maybe") }
      .to raise_error(DPay::InvalidArgumentError)
  end
end
