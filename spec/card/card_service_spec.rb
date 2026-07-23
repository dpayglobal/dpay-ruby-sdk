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

  it "captures with a float amount" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })

    service.capture("tx-1", DPay::Money.pln(1050))

    expect(transport.last_request.body).to eq('{"amount":10.5}')
    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/cards/payment/tx-1/capture")
  end

  it "cancels with and without an amount" do
    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    service.cancel("tx-1")
    expect(transport.last_request.body).to eq("{}")

    transport.queue_json(200, { "success" => true, "message" => { "redirectType" => "SUCCESS" } })
    service.cancel("tx-1", DPay::Money.pln(2000))
    expect(transport.last_request.body).to eq('{"amount":20}')
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
