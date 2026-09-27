# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::RecurringService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transaction_id) { "A75AEBB4-4B89-4834-AD43-EF442C133769" }
  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) do
    DPay::Config.new(service: "sdk-test-service", secret_hash: "sdk-test-hash-0001", http_client: transport)
  end
  let(:status_data) do
    {
      "alias" => "SUB-0001", "method" => "blik", "status" => "ACTIVE", "expiration_date" => "2027-09-30",
      "registration" => {
        "transaction_id" => transaction_id, "label" => "Abonament", "model" => "A", "frequency" => "1M",
        "limit_amt" => 5999, "tot_limit_amt" => 71_988, "is_limit_amt_fixed" => true, "init_date" => "2026-11-01",
        "terms_url" => "https://shop.example/terms", "terms_version" => "2026-09",
        "registered_at" => "2026-09-26T12:00:00+02:00"
      }
    }
  end

  it "signs the status request with the alias" do
    transport.queue_json(200, { "status" => "success", "data" => status_data })

    service.status("SUB-0001")

    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/payments/recurring/status")
    expect(transport.last_request_body).to eq(
      { "service" => "sdk-test-service", "alias" => "SUB-0001",
        "checksum" => "01e38925de1ceefbfbaffdf84a917f1c95123403a0e51a7d74cb81f227c3e3ef" }
    )
  end

  it "returns the status and terms of the recurring payment" do
    transport.queue_json(200, { "status" => "success", "data" => status_data })

    status = service.status("SUB-0001")

    expect(status).to be_active
    expect(status.alias).to eq("SUB-0001")
    expect(status.payment_method).to eq("blik")
    expect(status.expiration_date).to eq("2027-09-30")
    registration = status.registration
    expect(registration.transaction_id).to eq(transaction_id)
    expect(registration.model).to eq("A")
    expect(registration.limit_amt).to eq(5999)
    expect(registration.tot_limit_amt).to eq(71_988)
    expect(registration.limit_amt_fixed).to be(true)
    expect(registration.terms_url).to eq("https://shop.example/terms")
    expect(registration.terms_version).to eq("2026-09")
    expect(registration.registered_at).to eq("2026-09-26T12:00:00+02:00")
  end

  it "signs the cancellation with the operation name" do
    transport.queue_json(200, { "status" => "success",
                                "data" => { "alias" => "SUB-0001", "status" => "UNREGISTERED" } })

    expect(service.cancel("SUB-0001", "Rezygnacja")).to eq(DPay::RecurringStatus::UNREGISTERED)
    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/payments/recurring/cancel")
    expect(transport.last_request_body).to eq(
      { "service" => "sdk-test-service", "alias" => "SUB-0001", "reason" => "Rezygnacja",
        # sha256(service|hash|alias|cancel) - a status checksum cannot cancel
        "checksum" => "848c236b3060a94c2ed14c150de154ee7aa2d64ec3682771259c30321cadf82b" }
    )
  end

  it "cancels without a reason and defaults the status" do
    transport.queue_json(200, { "status" => "success", "data" => {} })

    expect(service.cancel("SUB-0001")).to eq("UNREGISTERED")
    expect(transport.last_request_body.keys).to eq(%w[service alias checksum])
  end

  it "returns a pending retry" do
    transport.queue_json(200, { "status" => "success",
                                "data" => { "transactionId" => transaction_id,
                                            "retry" => { "status" => "pending", "count" => 1 } } })

    result = service.retry(transaction_id)

    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/payments/recurring/retry")
    expect(transport.last_request_body).to eq(
      { "service" => "sdk-test-service", "transaction_id" => transaction_id,
        "checksum" => "00bceec5fca2ee4c3a1737156df376441d225790eb61ca47fcbe9cba7243a77d" }
    )
    expect(result).to be_pending
    expect(result.count).to eq(1)
    expect(result.transaction_id).to eq(transaction_id)
  end

  it "treats a retry declined at once as a result, not an error" do
    transport.queue_json(200, { "status" => "success", "data" => {
                           "transactionId" => transaction_id,
                           "retry" => { "status" => "failed", "count" => 2, "error" => "INSUFFICIENT_FUNDS",
                                        "error_description" => "IssId: 1" }
                         } })

    result = service.retry(transaction_id)

    expect(result).to be_failed
    expect(result).not_to be_pending
    expect(result.error_code).to eq("INSUFFICIENT_FUNDS")
    expect(result.error_description).to eq("IssId: 1")
  end

  it "carries the reason when the charge cannot be retried" do
    transport.queue_json(400, { "status" => "failed",
                                "message" => "Recurring charge cannot be retried (DECLINE_NOT_RETRYABLE).",
                                "errors" => { "retry" => "DECLINE_NOT_RETRYABLE",
                                              "decline_reason" => "SEC_DECLINED" } })

    expect { service.retry(transaction_id) }.to raise_error(DPay::InvalidRequestError) { |error|
      expect(error.field_errors["retry"]).to eq(["DECLINE_NOT_RETRYABLE"])
      expect(error.http_status).to eq(400)
    }
  end
end
