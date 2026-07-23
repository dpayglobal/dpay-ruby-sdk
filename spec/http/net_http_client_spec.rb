# frozen_string_literal: true

RSpec.describe DPay::HTTP::NetHTTPClient do
  subject(:client) { described_class.new }

  let(:http_double) { instance_double(Net::HTTP) }

  def stub_transport
    allow(Net::HTTP).to receive(:new).and_return(http_double)
    allow(http_double).to receive(:use_ssl=)
    allow(http_double).to receive(:open_timeout=)
    allow(http_double).to receive(:read_timeout=)
    allow(http_double).to receive(:write_timeout=)
  end

  def net_response(code, body, headers = {})
    instance_double(Net::HTTPResponse, code: code.to_s, body: body, each_header: headers)
  end

  it "raises DPay::TransportError for a non-http(s) scheme before touching Net::HTTP" do
    allow(Net::HTTP).to receive(:new)

    expect { client.request(DPay::HTTP::Request.new("GET", "ws://example.com/x")) }
      .to raise_error(DPay::TransportError, "Unsupported URL scheme: ws://example.com/x")

    expect(Net::HTTP).not_to have_received(:new)
  end

  it "maps a successful response to a DPay::HTTP::Response" do
    stub_transport
    headers = { "Content-Type" => "application/json" }
    allow(http_double).to receive(:request).and_return(net_response(200, '{"ok":true}', headers))

    response = client.request(DPay::HTTP::Request.new("GET", "https://api.example.com/x"))

    expect(response).to be_a(DPay::HTTP::Response)
    expect(response.status).to eq(200)
    expect(response.status).to be_a(Integer)
    expect(response.body).to eq('{"ok":true}')
    expect(response.header("content-type")).to eq("application/json")
  end

  it "wraps a network failure in DPay::TransportError instead of letting it escape" do
    stub_transport
    allow(http_double).to receive(:request).and_raise(SocketError, "getaddrinfo failed")

    expect { client.request(DPay::HTTP::Request.new("GET", "https://api.example.com/x")) }
      .to raise_error(DPay::TransportError, "HTTP transport error: SocketError: getaddrinfo failed")
  end

  it "also wraps a timeout error in DPay::TransportError" do
    stub_transport
    allow(http_double).to receive(:request).and_raise(Timeout::Error)

    expect { client.request(DPay::HTTP::Request.new("GET", "https://api.example.com/x")) }
      .to raise_error(DPay::TransportError)
  end

  it "enables SSL for https URLs and disables it for http URLs" do
    stub_transport
    allow(http_double).to receive(:request).and_return(net_response(200, ""))

    client.request(DPay::HTTP::Request.new("GET", "https://api.example.com/x"))
    expect(http_double).to have_received(:use_ssl=).with(true)

    client.request(DPay::HTTP::Request.new("GET", "http://api.example.com/x"))
    expect(http_double).to have_received(:use_ssl=).with(false)
  end
end
