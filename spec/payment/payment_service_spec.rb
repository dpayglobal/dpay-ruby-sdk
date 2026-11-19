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

  it "returns no paid transaction or Multibanco reference for a plain registration" do
    transport.queue_json(200, { "transactionId" => "tx-1", "msg" => "https://secure.dpay.pl/pay/1" })

    payment = service.register(DPay::RegisterPaymentRequest.create(DPay::Money.pln(100), "transfers", urls))

    expect(payment.paid_transaction).to be_nil
    expect(payment.multibanco).to be_nil
  end

  it "returns the paid transaction of a Transaction paid answer in the request currency" do
    transport.queue_json(200, {
                           "error" => false, "msg" => "Transaction paid", "status" => true,
                           "transactionId" => "30D9493D-1D73-3FBD-A5D4-633723CC7A68",
                           "additionalInfo" => { "transaction" => {
                             "payment_id" => "30D9493D-1D73-3FBD-A5D4-633723CC7A68", "pid" => nil, "mtid" => nil,
                             "email" => "client@example.com", "description" => "Zamowienie #1234", "name" => "Jan",
                             "surname" => "Kowalski", "value" => "10.00", "status" => "paid",
                             "creation_date" => "2026-11-18 10:00:00", "payment_date" => "2026-11-18 10:01:00"
                           } }
                         })

    transaction = service.register(DPay::RegisterPaymentRequest.create(DPay::Money.pln(1000), "transfers", urls))
                         .paid_transaction

    expect(transaction.payment_id).to eq("30D9493D-1D73-3FBD-A5D4-633723CC7A68")
    expect(transaction.status).to eq(DPay::RegisteredTransaction::STATUS_PAID)
    expect(transaction).to be_paid
    expect(transaction.value).to eq(DPay::Money.pln(1000))
    expect(transaction.email).to eq("client@example.com")
    expect(transaction.description).to eq("Zamowienie #1234")
    expect(transaction.name).to eq("Jan")
    expect(transaction.surname).to eq("Kowalski")
    expect(transaction.pid).to be_nil
    expect(transaction.mtid).to be_nil
    expect(transaction.creation_date).to eq("2026-11-18 10:00:00")
    expect(transaction.payment_date).to eq("2026-11-18 10:01:00")
  end

  it "returns the Multibanco reference and sends the euro currency" do
    transport.queue_json(200, { "error" => false, "msg" => "https://secure.dpay.pl/transfer@pay@ABC", "status" => true,
                                "transactionId" => "ABC",
                                "multibanco" => { "entity" => "12345", "reference" => "123456789", "amount" => "12.50",
                                                  "currency" => "EUR", "expires_at" => "2026-11-21T10:00:00+00:00" } })
    request = DPay::RegisterPaymentRequest.create(DPay::Money.of(1250, DPay::Currency::EUR), "transfers", urls)
                                          .with_channel("390")
                                          .with_payer(DPay::Payer.create.with_email("client@example.com")
                                                                 .with_name("Joao", "Silva"))
                                          .with_accept_tos(true)

    multibanco = service.register(request).multibanco

    expect(transport.last_request_body["currency_code"]).to eq("EUR")
    expect(multibanco.entity).to eq("12345")
    expect(multibanco.reference).to eq("123456789")
    expect(multibanco.amount).to eq(DPay::Money.of(1250, "EUR"))
    expect(multibanco.currency).to eq("EUR")
    expect(multibanco.expires_at).to eq("2026-11-21T10:00:00+00:00")
  end

  it "reads the registration models with fallbacks" do
    multibanco = DPay::MultibancoReference.from_api({ "entity" => 12_345, "currency" => "eur", "amount" => "x" })
    euro = DPay::RegisteredPayment.from_api(
      { "additionalInfo" => { "transaction" => { "value" => 12.5, "status" => "captured" } } }, "EUR"
    ).paid_transaction

    expect(multibanco.entity).to eq("12345")
    expect(multibanco.reference).to eq("")
    expect(multibanco.currency).to eq("EUR")
    expect(multibanco.amount).to be_nil
    expect(multibanco.expires_at).to be_nil
    expect(euro.value).to eq(DPay::Money.of(1250, "EUR"))
    expect(euro).to be_paid
    expect(euro.payment_id).to eq("")
    expect(DPay::RegisteredTransaction.from_api({ "status" => "canceled" }, "bad")).not_to be_paid
    expect(DPay::RegisteredTransaction.from_api({ "value" => "1.00" }, "bad").value).to eq(DPay::Money.pln(100))
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
