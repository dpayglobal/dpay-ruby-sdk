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

  it "returns a missing transaction on 404 as an availability outcome" do
    transport.queue_json(404, { "status" => "error", "refund" => false, "message" => "Transaction does not exist!",
                                "0" => "Transaction does not exist!" })

    availability = service.check_availability("TX-404")

    expect(availability).not_to be_available
    expect(availability.message).to eq("Transaction does not exist!")
    expect(availability.http_status).to eq(404)
  end

  it "returns a buyer support refusal on 423 and a business 401 as availability outcomes" do
    transport.queue_json(423, { "status" => "error", "refund" => false, "code" => "BUYER_SUPPORT_REFUND_NOT_APPLICABLE",
                                "message" => "Zwrot przez BOK dpay" })
    expect(service.check_availability("TX-1").http_status).to eq(423)

    transport.queue_json(401, { "refund" => false,
                                "message" => "Transakcji dokonanych kanałami paysafecard nie można zwrócić" })
    expect(service.check_availability("TX-1").http_status).to eq(401)
  end

  it "raises without the refund key and on server errors" do
    transport.queue_json(404, { "message" => "Not Found" })
    expect { service.check_availability("TX-1") }.to raise_error(DPay::NotFoundError)

    transport.queue_json(500, { "status" => "error", "refund" => false, "message" => "Server error" })
    expect { service.check_availability("TX-1") }.to raise_error(DPay::ApiServerError)

    transport.queue_json(401, { "refund" => false, "message" => "Unauthorized request" })
    expect { service.check_availability("TX-1") }.to raise_error(DPay::AuthenticationError)
  end

  it "decides availability by the refund key: 422 and 429 without it raise, 422 with it is an answer" do
    transport.queue_json(422, { "message" => "The transaction id field is required.",
                                "errors" => { "transaction_id" => ["The transaction id field is required."] } })
    expect { service.check_availability("TX-1") }
      .to raise_error(DPay::InvalidRequestError) { |error| expect(error.http_status).to eq(422) }

    transport.queue_json(429, { "status" => "error", "message" => "Too Many Requests", "error" => "Too Many Requests" },
                         { "Retry-After" => "12" })
    expect { service.check_availability("TX-1") }
      .to raise_error(DPay::RateLimitError) { |error| expect(error.retry_after).to eq(12) }

    transport.queue_json(422, { "status" => "error", "refund" => false, "message" => "Refund not possible" })
    availability = service.check_availability("TX-1")
    expect(availability).not_to be_available
    expect(availability.http_status).to eq(422)
  end

  context "with strings the panel API trims" do
    let(:service_name) { "MyShop" }
    let(:config) { DPay::Config.new(service: service_name, secret_hash: "secret123", http_client: transport) }
    let(:transaction_id) { "30D9493D-1D73-3FBD-A5D4-633723CC7A68" }

    context "with surrounding whitespace in the configured service" do
      let(:service_name) { " MyShop " }

      it "sends and signs the trimmed service, transaction id and reason" do
        transport.queue_json(200, { "status" => "success", "refund" => true })

        service.create(" #{transaction_id}\n", DPay::Money.pln(1500), "\u3000reklamacja\u200B")

        expect(transport.last_request_body).to eq(
          { "service" => "MyShop", "transaction_id" => transaction_id, "value" => "15.00", "reason" => "reklamacja",
            "checksum" => "5c00684addf39fda89d3d6cff88abf26bb8173119056fd3012050422943c798a" }
        )
      end
    end

    it "sends a reason that is blank after trimming as an empty string" do
      transport.queue_json(200, { "refund" => true })

      service.check_availability(transaction_id, DPay::Money.pln(1500), "\uFEFF \n")

      body = transport.last_request_body
      expect(body.keys).to eq(%w[service transaction_id value reason checksum])
      expect(body["reason"]).to eq("")
      expect(body["checksum"]).to eq("12dcb016aa2302bbe8ea71be9007eeacdedaeab1d4dc317966bab1b1e8d53a1c")
    end

    it "sends a trimmed webhook URL" do
      transport.queue_json(200, { "status" => "success", "refund" => true })

      service.create(transaction_id, nil, nil,
                     DPay::WebhookTarget.create("https://shop.example/webhooks/refunds\u200B", ["refund.succeeded"]))

      expect(transport.last_request_body["webhook"]["url"]).to eq("https://shop.example/webhooks/refunds")
      expect(transport.last_request_body["checksum"]).to eq(
        Digest::SHA256.hexdigest("MyShop|#{transaction_id}|https://shop.example/webhooks/refunds|refund.succeeded|" \
                                 "secret123")
      )
    end

    it "rejects a transaction id that is blank after trimming before sending" do
      expect { service.create(" \t") }
        .to raise_error(DPay::InvalidArgumentError, "transaction_id must not be empty")
      expect { service.check_availability("") }
        .to raise_error(DPay::InvalidArgumentError, "transaction_id must not be empty")
      expect { service.create(" ", nil, nil, nil, "RET\n") }
        .to raise_error(DPay::InvalidArgumentError, "Refund message ID must be non-empty printable ASCII")
      expect(transport.requests).to be_empty
    end

    context "with a blank configured service" do
      let(:service_name) { "\u3000" }

      it "rejects the request before the transaction id" do
        expect { service.create(" ") }.to raise_error(DPay::InvalidArgumentError, "service must not be empty")
        expect { service.check_availability(" ") }
          .to raise_error(DPay::InvalidArgumentError, "service must not be empty")
        expect(transport.requests).to be_empty
      end
    end
  end

  context "with a refund message id" do
    let(:config) { DPay::Config.new(service: "MyShop", secret_hash: "secret123", http_client: transport) }

    it "sends the message id in the header, outside the checksum" do
      transport.queue_json(200, { "status" => "success", "refund" => true, "message" => "dpay.pl zwrot RET-2026-0001" })

      refund = service.create("30D9493D-1D73-3FBD-A5D4-633723CC7A68", nil, nil, nil, "RET-2026-0001")

      body = transport.last_request_body
      expect(refund.message).to eq("dpay.pl zwrot RET-2026-0001")
      expect(transport.last_request.headers[DPay::RefundService::MESSAGE_ID_HEADER]).to eq("RET-2026-0001")
      expect(body.keys).to eq(%w[service transaction_id checksum])
      expect(body["checksum"]).to eq("3b345f55900ae6a43220dd14a3827ed9a26a02a3eb46b856d302e2baa44b48a4")
    end

    it "sends no header without a message id" do
      transport.queue_json(200, { "status" => "success", "refund" => true, "message" => "dpay.pl TX" })

      service.create("TX-1")

      expect(transport.last_request.headers).not_to have_key("DigitalPayments-PSP-Message-ID")
    end

    it "rejects a message id that is not non-empty printable ASCII" do
      ["", "   ", "RET\r\nX-Evil: 1", "ZWROT-ŁÓDŹ", "RET-1\n", 42].each do |message_id|
        expect { service.create("TX-1", nil, nil, nil, message_id) }
          .to raise_error(DPay::InvalidArgumentError, "Refund message ID must be non-empty printable ASCII")
      end
      expect(transport.requests).to be_empty
    end
  end

  it "keeps the refund_full vector unchanged by a message id" do
    vector = ApiVectors.data["ordered_body"].find { |item| item["name"] == "refund_full" }
    vectors_config = DPay::Config.new(service: ApiVectors.data["service"], secret_hash: ApiVectors.data["secret_hash"],
                                      http_client: transport)
    vectors_service = described_class.new(DPay::Internal::ApiRequestor.new(vectors_config, transport))
    transport.queue_json(200, { "status" => "success", "refund" => true })

    vectors_service.create(vector["body"]["transaction_id"], nil, nil, nil, "RET-1")

    expect(transport.last_request_body["checksum"]).to eq(vector["checksum"])
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
