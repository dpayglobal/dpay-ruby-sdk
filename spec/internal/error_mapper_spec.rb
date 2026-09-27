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
