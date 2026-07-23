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
end
