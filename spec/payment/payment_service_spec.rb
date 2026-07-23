# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::PaymentService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "test_service", secret_hash: "sekret-hash-123", http_client: transport) }
  let(:urls) { DPay::ReturnUrls.new("https://shop.test/ok", "https://shop.test/fail", "https://shop.test/ipn") }

  it "registers a payment with the register checksum" do
    transport.queue_json(200, { "transactionId" => "tx-1", "msg" => "https://secure.dpay.pl/pay/1" })

    payment = service.register(
      DPay::RegisterPaymentRequest.create(DPay::Money.pln(2999), DPay::TransactionType::TRANSFERS, urls)
    )

    body = transport.last_request_body
    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/payments/register")
    expect(body["value"]).to eq("29.99")
    expect(body["checksum"]).to eq("056198b45db5fcec2140233fbc8b3b0929fdad82c0a678933c91b8d561ac7058")
    expect(body.keys.last).to eq("checksum")
    expect(payment.transaction_id).to eq("tx-1")
  end

  it "raises PaymentRejectedError on an HTTP 200 rejection" do
    transport.queue_json(200, { "error" => true, "errorcode" => "err12", "message" => "Rejected",
                                "transactionId" => "tx-9" })

    expect do
      service.register(
        DPay::RegisterPaymentRequest.create(DPay::Money.pln(100), DPay::TransactionType::TRANSFERS, urls)
      )
    end.to raise_error(DPay::PaymentRejectedError) { |error| expect(error.transaction_id).to eq("tx-9") }
  end

  it "fetches transaction details with the ordered body checksum" do
    transport.queue_json(200, { "transaction" => { "id" => "tx-1", "status" => "paid" } })

    transaction = service.details("tx-1")

    body = transport.last_request_body
    expect(transport.last_request.url).to eq("https://panel.dpay.pl/api/v1/pbl/details")
    expect(body["service"]).to eq("test_service")
    expect(body["transaction_id"]).to eq("tx-1")
    expect(body["checksum"]).to eq("9508d77a17bdd44829ecc450214a3e356ca0cbe2f93c28012e3a5f6b39b4aa30")
    expect(transaction).to be_paid
  end
end
