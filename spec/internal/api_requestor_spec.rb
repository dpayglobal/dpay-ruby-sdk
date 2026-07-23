# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::Internal::ApiRequestor do
  subject(:requestor) { described_class.new(config, transport) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "MyShop", secret_hash: "secret123", http_client: transport) }

  it "builds a signed JSON request with SDK headers" do
    transport.queue_json(200, { "ok" => true })

    result = requestor.post_json(DPay::Internal::BaseUrls::PANEL, "/api/v1/pbl/details", { "service" => "MyShop" })

    request = transport.last_request
    expect(result).to eq({ "ok" => true })
    expect(request.method).to eq("POST")
    expect(request.url).to eq("https://panel.dpay.pl/api/v1/pbl/details")
    expect(request.headers["Accept"]).to eq("application/json")
    expect(request.headers["Content-Type"]).to eq("application/json")
    expect(request.headers["User-Agent"]).to eq("dpay-ruby-sdk/#{DPay::VERSION} ruby/#{RUBY_VERSION}")
    expect(request.body).to eq('{"service":"MyShop"}')
  end

  it "omits the content type when there is no body" do
    transport.queue_json(200, [])

    requestor.get_json(DPay::Internal::BaseUrls::PANEL, "/api/v1/pbl/banks")

    expect(transport.last_request.headers).not_to have_key("Content-Type")
    expect(transport.last_request.body).to be_nil
  end

  it "encodes an empty body as an empty JSON object" do
    transport.queue_json(200, { "ok" => true })

    requestor.post_json(DPay::Internal::BaseUrls::API_PAYMENTS, "/x", {})

    expect(transport.last_request.body).to eq("{}")
  end

  it "raises a mapped error for HTTP failures" do
    transport.queue_json(401, { "message" => "Unauthorized request" })

    expect { requestor.post_json(DPay::Internal::BaseUrls::PANEL, "/x", {}) }
      .to raise_error(DPay::AuthenticationError, "Unauthorized request")
  end

  it "returns the raw response without raising through send_raw" do
    transport.queue_json(409, { "refund" => false })

    response = requestor.send_raw("POST", DPay::Internal::BaseUrls::PANEL, "/x", {})

    expect(response.status).to eq(409)
  end

  it "raises ApiServerError when a 2xx body is not JSON" do
    transport.queue_text(200, "not-json")

    expect { requestor.post_json(DPay::Internal::BaseUrls::PANEL, "/x", {}) }
      .to raise_error(DPay::ApiServerError)
  end

  it "returns plain text through get_text" do
    transport.queue_text(200, "-----BEGIN PUBLIC KEY-----\n")

    expect(requestor.get_text(DPay::Internal::BaseUrls::API_PAYMENTS, "/k")).to eq("-----BEGIN PUBLIC KEY-----\n")
  end
end
