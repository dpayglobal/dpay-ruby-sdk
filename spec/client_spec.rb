# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::Client do
  subject(:client) do
    described_class.new(
      service: "test_service",
      secret_hash: "sekret-hash-123",
      http_client: transport
    )
  end

  let(:transport) { DPay::Testing::MockHttpClient.new }

  it "exposes every service" do
    expect(client.payments).to be_a(DPay::PaymentService)
    expect(client.refunds).to be_a(DPay::RefundService)
    expect(client.banks).to be_a(DPay::BankService)
    expect(client.blik).to be_a(DPay::BlikService)
    expect(client.cards).to be_a(DPay::CardService)
    expect(client.payouts).to be_a(DPay::PayoutService)
  end

  it "shares one configuration across services" do
    transport.queue_json(200, { "transaction" => { "id" => "tx-1", "status" => "paid" } })

    client.payments.details("tx-1")

    expect(client.config.service).to eq("test_service")
    expect(transport.last_request_body["service"]).to eq("test_service")
  end

  it "defaults to the Net::HTTP transport" do
    default_client = described_class.new(service: "s", secret_hash: "x")

    expect(default_client.config.http_client).to be_nil
  end

  it "exposes the SDK version" do
    expect(described_class::VERSION).to eq(DPay::VERSION)
  end

  it "validates configuration eagerly" do
    expect { described_class.new(service: "", secret_hash: "x") }.to raise_error(DPay::InvalidArgumentError)
  end
end
