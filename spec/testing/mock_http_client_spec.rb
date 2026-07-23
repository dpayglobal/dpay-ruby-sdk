# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::Testing::MockHttpClient do
  subject(:transport) { described_class.new }

  it "returns queued responses in FIFO order and records requests" do
    transport.queue_json(200, { "ok" => true })
    request = DPay::HTTP::Request.new("POST", "https://api.example/x", {}, '{"a":1}')

    response = transport.request(request)

    expect(response.status).to eq(200)
    expect(response.decode_json).to eq({ "ok" => true })
    expect(transport.last_request).to be(request)
    expect(transport.last_request_body).to eq({ "a" => 1 })
    expect(transport.requests.size).to eq(1)
  end

  it "raises when the queue is empty" do
    expect { transport.request(DPay::HTTP::Request.new("GET", "https://api.example/x")) }
      .to raise_error(/queue is empty/)
  end
end
