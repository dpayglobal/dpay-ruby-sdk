# frozen_string_literal: true

RSpec.describe DPay::Error do
  it "carries HTTP context on ApiError" do
    error = DPay::ApiError.new("Invalid checksum", 400, "err01", { "value" => ["required"] }, '{"status":"failed"}')

    expect(error.message).to eq("Invalid checksum")
    expect(error.http_status).to eq(400)
    expect(error.error_code).to eq("err01")
    expect(error.field_errors).to eq({ "value" => ["required"] })
    expect(error.raw_body).to eq('{"status":"failed"}')
  end

  it "defaults optional ApiError context" do
    error = DPay::ApiError.new("Boom", 500)

    expect(error.error_code).to be_nil
    expect(error.field_errors).to eq({})
    expect(error.raw_body).to eq("")
    expect(error.reason).to be_nil
  end

  it "carries the reason next to the error code" do
    error = DPay::InvalidRequestError.new("Invalid webhook URL", 400, "WEBHOOK_URL_INVALID", {}, "{}", "own_domain")

    expect(error.reason).to eq("own_domain")
  end

  it "reads the provider decline of a BLIK payment from additionalInfo" do
    error = DPay::PaymentRejectedError.from_api(
      { "error" => true, "msg" => "Transaction canceled", "status" => false, "transactionId" => "tx-7",
        "additionalInfo" => { "error" => "INSUFFICIENT_FUNDS", "error_description" => "IssId: 1" } }
    )

    expect(error.message).to eq("Transaction canceled")
    expect(error.error_code).to eq("INSUFFICIENT_FUNDS")
    expect(error.error_description).to eq("IssId: 1")
    expect(error.transaction_id).to eq("tx-7")
  end

  it "exposes every SDK error through the DPay::Error marker" do
    expect(DPay::TransportError.new("x")).to be_a(described_class)
    expect(DPay::InvalidRequestError.new("x", 422)).to be_a(described_class)
    expect(DPay::InvalidArgumentError.new("x")).to be_a(described_class)
    expect(DPay::InvalidRequestError.new("x", 422)).to be_a(DPay::ApiError)
  end

  it "keeps InvalidArgumentError catchable as ArgumentError" do
    expect { raise DPay::InvalidArgumentError, "bad" }.to raise_error(ArgumentError)
  end

  it "carries rate limit context" do
    error = DPay::RateLimitError.new("Too many requests", 429, 30, 120, 0, "{}")

    expect(error.retry_after).to eq(30)
    expect(error.limit).to eq(120)
    expect(error.remaining).to eq(0)
    expect(error.http_status).to eq(429)
  end

  it "builds PaymentRejectedError from an HTTP 200 rejection envelope" do
    error = DPay::PaymentRejectedError.from_api(
      { "error" => true, "errorcode" => "err12", "message" => "Rejected", "transactionId" => "tx-9" }
    )

    expect(error.message).to eq("Rejected")
    expect(error.http_status).to eq(200)
    expect(error.error_code).to eq("err12")
    expect(error.transaction_id).to eq("tx-9")
  end

  it "builds CardPaymentError with error_code mirroring the message" do
    error = DPay::CardPaymentError.from_api({ "success" => false, "message" => "DCC_OFFER_EXPIRED" })

    expect(error.message).to eq("DCC_OFFER_EXPIRED")
    expect(error.error_code).to eq("DCC_OFFER_EXPIRED")
    expect(error.http_status).to eq(200)
  end

  it "allows rate limit context to be omitted" do
    error = DPay::RateLimitError.new("Too many requests", 429)

    expect(error.retry_after).to be_nil
    expect(error.limit).to be_nil
    expect(error.remaining).to be_nil
    expect(error.raw_body).to eq("")
  end

  it "allows payment rejection context to be omitted" do
    error = DPay::PaymentRejectedError.new("Rejected", 200)

    expect(error.error_code).to be_nil
    expect(error.field_errors).to eq({})
    expect(error.raw_body).to eq("")
    expect(error.transaction_id).to be_nil
    expect(error.error_description).to be_nil
  end
end
