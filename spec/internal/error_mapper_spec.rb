# frozen_string_literal: true

RSpec.describe DPay::Internal::ErrorMapper do
  def map(status, body, headers = {})
    described_class.map(DPay::HTTP::Response.new(status, headers, body))
  end

  it "maps 400 with string field errors" do
    body = '{"status":"failed","message":"Invalid checksum","errors":{"value":"The value field is required."}}'
    error = map(400, body)

    expect(error).to be_a(DPay::InvalidRequestError)
    expect(error.message).to eq("Invalid checksum")
    expect(error.field_errors).to eq({ "value" => ["The value field is required."] })
    expect(error.raw_body).to eq(body)
  end

  it "maps 422 with array field errors" do
    error = map(422, '{"message":"Validation failed","errors":{"email":["Invalid email","Too long"]}}')

    expect(error).to be_a(DPay::InvalidRequestError)
    expect(error.field_errors).to eq({ "email" => ["Invalid email", "Too long"] })
  end

  it "maps status codes to dedicated classes" do
    expect(map(401, '{"message":"Unauthorized request"}')).to be_a(DPay::AuthenticationError)
    expect(map(403, '{"errorcode":"err01","message":"Access denied"}')).to be_a(DPay::AccessDeniedError)
    expect(map(404, '{"message":"Not found"}')).to be_a(DPay::NotFoundError)
    expect(map(500, "Internal Server Error")).to be_a(DPay::ApiServerError)
    expect(map(418, "{}")).to be_an_instance_of(DPay::ApiError)
  end

  it "extracts the error code" do
    expect(map(403, '{"errorcode":"err01","message":"Access denied"}').error_code).to eq("err01")
  end

  it "maps 429 with rate limit headers" do
    error = map(429, '{"message":"Too Many Attempts."}',
                { "Retry-After" => "30", "X-RateLimit-Limit" => "120", "X-RateLimit-Remaining" => "0" })

    expect(error).to be_a(DPay::RateLimitError)
    expect(error.retry_after).to eq(30)
    expect(error.limit).to eq(120)
    expect(error.remaining).to eq(0)
    expect(error.reset).to be_nil
  end

  it "maps the rate limit reset header" do
    error = map(429, '{"message":"Too Many Attempts."}',
                { "retry-after" => "12", "x-ratelimit-limit" => "60", "x-ratelimit-remaining" => "0",
                  "x-ratelimit-reset" => "1790503560" })

    expect(error).to be_a(DPay::RateLimitError)
    expect(error.reset).to eq(1_790_503_560)
    expect(error.retry_after).to eq(12)
    expect(error.limit).to eq(60)
    expect(error.remaining).to eq(0)
  end

  it "carries the transaction id and the card decline of a Payments API error" do
    body = '{"status":"failed","message":"Card payment declined","errors":{},' \
           '"transactionId":"A75AEBB4-4B89-4834-AD43-EF442C133769","cardError":{"code":"payment_declined",' \
           '"declineCode":"51","declineMessage":"Insufficient funds or over credit limit"}}'
    error = map(400, body)

    expect(error).to be_a(DPay::InvalidRequestError)
    expect(error.transaction_id).to eq("A75AEBB4-4B89-4834-AD43-EF442C133769")
    expect(error.card_error.code).to eq("payment_declined")
    expect(error.card_error.decline_code).to eq("51")
    expect(error.card_error.decline_message).to eq("Insufficient funds or over credit limit")
  end

  it "keeps the null fields of a card decline" do
    body = '{"status":"failed","message":"Declined","cardError":{"code":"payment_declined","declineCode":null,' \
           '"declineMessage":null}}'
    card_error = map(400, body).card_error

    expect(card_error.code).to eq("payment_declined")
    expect(card_error.decline_code).to be_nil
    expect(card_error.decline_message).to be_nil
  end

  it "passes the transaction context to every status class except 429" do
    body = '{"message":"x","transactionId":"TX-1","cardError":{"code":"invalid_card","declineCode":5}}'

    [401, 403, 404, 422, 418, 502].each do |status|
      error = map(status, body)
      expect(error.transaction_id).to eq("TX-1"), status.to_s
      expect(error.card_error.decline_code).to eq("5"), status.to_s
    end
    expect(map(429, body).transaction_id).to be_nil
  end

  it "has no transaction context without the fields or with malformed ones" do
    error = map(400, '{"status":"failed","message":"Invalid checksum","errors":{}}')

    expect(error.transaction_id).to be_nil
    expect(error.card_error).to be_nil
    malformed = map(400, '{"message":"x","transactionId":"","cardError":"declined"}')
    expect(malformed.transaction_id).to be_nil
    expect(malformed.card_error).to be_nil
    expect(map(400, '{"message":"x","transactionId":42}').transaction_id).to be_nil
  end

  it "falls back to the msg key and a default message" do
    expect(map(400, '{"error":true,"msg":"Bad request"}').message).to eq("Bad request")
    expect(map(500, "boom").message).to eq("Unexpected API error")
  end

  it "maps the code and reason of cards and webhook errors" do
    body = '{"success":false,"status":"error","code":"WEBHOOK_URL_INVALID","reason":"https_required",' \
           '"message":"Invalid webhook URL: https_required"}'
    error = map(400, body)

    expect(error).to be_a(DPay::InvalidRequestError)
    expect(error.error_code).to eq("WEBHOOK_URL_INVALID")
    expect(error.reason).to eq("https_required")
    expect(error.message).to eq("Invalid webhook URL: https_required")
  end

  it "maps a missing checksum to an authentication error" do
    error = map(
      401, '{"success":false,"status":"error","code":"CHECKSUM_REQUIRED","message":"Missing service or checksum"}'
    )

    expect(error).to be_a(DPay::AuthenticationError)
    expect(error.error_code).to eq("CHECKSUM_REQUIRED")
    expect(error.reason).to be_nil
  end

  it "prefers code over the legacy errorcode" do
    expect(map(409, '{"code":"CONNECT_REFUND_REQUIRES_FINANCIAL_PLAN","errorcode":"err01"}').error_code)
      .to eq("CONNECT_REFUND_REQUIRES_FINANCIAL_PLAN")
  end

  it "keeps field errors sent as an empty JSON list" do
    error = map(400, '{"status":"failed","message":"Recurring payments are not available.","errors":[]}')

    expect(error.field_errors).to eq({})
  end
end
