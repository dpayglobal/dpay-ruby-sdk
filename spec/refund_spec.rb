# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::RefundService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "test_service", secret_hash: "sekret-hash-123", http_client: transport) }

  it "creates a full refund" do
    transport.queue_json(200, { "status" => "success", "refund" => true, "message" => "ok" })

    refund = service.create("tx-1")

    body = transport.last_request_body
    expect(transport.last_request.url).to eq("https://panel.dpay.pl/api/v1/pbl/refund")
    expect(body.keys).to eq(%w[service transaction_id checksum])
    expect(body["checksum"]).to eq("9508d77a17bdd44829ecc450214a3e356ca0cbe2f93c28012e3a5f6b39b4aa30")
    expect(refund).to be_accepted
    expect(refund.message).to eq("ok")
  end

  it "creates a partial refund with a reason in checksum order" do
    transport.queue_json(200, { "status" => "success", "refund" => true })

    service.create("tx-1", DPay::Money.pln(1050), "reklamacja / zwrot")

    body = transport.last_request_body
    expect(body.keys).to eq(%w[service transaction_id value reason checksum])
    expect(body["value"]).to eq("10.50")
    expect(body["reason"]).to eq("reklamacja / zwrot")
    expect(body["checksum"]).to eq("1640c0b2f5afdb6b8cd408260a1a544308069d73608c993a9c65f00192d6281a")
  end

  it "treats a business rejection as an availability outcome, not an error" do
    transport.queue_json(409, { "refund" => false, "message" => "Refund not available" })

    availability = service.check_availability("tx-1")

    expect(availability).not_to be_available
    expect(availability.http_status).to eq(409)
    expect(availability.message).to eq("Refund not available")
  end

  it "reports availability on 200" do
    transport.queue_json(200, { "refund" => true })

    expect(service.check_availability("tx-1", DPay::Money.pln(500))).to be_available
  end

  it "maps a genuine auth failure to an error" do
    transport.queue_json(401, { "message" => "Unauthorized request" })

    expect { service.check_availability("tx-1") }.to raise_error(DPay::AuthenticationError)
  end

  it "marks an unaccepted refund" do
    transport.queue_json(200, { "status" => "failed", "refund" => false, "message" => "nope" })

    expect(service.create("tx-1")).not_to be_accepted
  end

  context "with a webhook target" do
    let(:config) do
      DPay::Config.new(service: "sdk-test-service", secret_hash: "sdk-test-hash-0001", http_client: transport)
    end

    it "hashes the webhook values in the order they are sent" do
      transport.queue_json(200, { "status" => "success", "refund" => true,
                                  "message" => "dpay.pl A75AEBB4-4B89-4834-AD43-EF442C133769" })

      service.create(
        "A75AEBB4-4B89-4834-AD43-EF442C133769", DPay::Money.pln(1500), "Zwrot",
        DPay::WebhookTarget.create("https://shop.example/webhooks/refunds", %w[refund.succeeded refund.failed])
      )

      body = transport.last_request_body
      expect(body.keys).to eq(%w[service transaction_id value reason webhook checksum])
      expect(body["value"]).to eq("15.00")
      expect(body["webhook"]).to eq(
        { "url" => "https://shop.example/webhooks/refunds", "events" => %w[refund.succeeded refund.failed] }
      )
      # ...|15.00|Zwrot|https://shop.example/webhooks/refunds|refund.succeeded|refund.failed|hash
      expect(body["checksum"]).to eq("53620f0ea6b46723866a46f2f0059c79cbe080e59d4f134508546be3fa08dacf")
    end

    it "accepts only refund events" do
      target = DPay::WebhookTarget.create("https://shop.example/webhooks", ["payment.succeeded"])

      expect { service.create("tx-1", nil, nil, target) }
        .to raise_error(DPay::InvalidArgumentError, /webhook object of a refund/)
      expect(transport.requests).to be_empty
    end
  end
end
