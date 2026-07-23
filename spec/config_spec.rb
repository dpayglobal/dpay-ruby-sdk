# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::Config do
  it "applies defaults" do
    config = described_class.new(service: "MyShop", secret_hash: "secret123")

    expect(config.service).to eq("MyShop")
    expect(config.secret_hash).to eq("secret123")
    expect(config.timeout).to eq(30)
    expect(config.http_client).to be_nil
    expect(config.base_urls.resolve(:panel)).to eq("https://panel.dpay.pl")
    expect(config.base_urls.resolve(:api_payments)).to eq("https://api-payments.dpay.pl")
    expect(config.base_urls.resolve(:gateway)).to eq("https://secure.dpay.pl")
  end

  it "accepts overrides and strips trailing slashes" do
    transport = DPay::Testing::MockHttpClient.new
    config = described_class.new(
      service: "MyShop", secret_hash: "secret123", timeout: 5,
      http_client: transport, base_urls: { api_payments: "https://mock.local/" }
    )

    expect(config.timeout).to eq(5)
    expect(config.http_client).to be(transport)
    expect(config.base_urls.resolve(:api_payments)).to eq("https://mock.local")
    expect(config.base_urls.resolve(:panel)).to eq("https://panel.dpay.pl")
  end

  it "rejects invalid options" do
    expect { described_class.new(secret_hash: "x") }.to raise_error(ArgumentError)
    expect { described_class.new(service: "MyShop", secret_hash: "") }.to raise_error(DPay::InvalidArgumentError)
    expect { described_class.new(service: "MyShop", secret_hash: "x", timeout: 0) }
      .to raise_error(DPay::InvalidArgumentError)
    expect { described_class.new(service: "MyShop", secret_hash: "x", base_urls: { gate: "https://x" }) }
      .to raise_error(DPay::InvalidArgumentError)
    expect { described_class.new(service: "MyShop", secret_hash: "x", secretHash: "typo") }
      .to raise_error(ArgumentError)
  end
end
