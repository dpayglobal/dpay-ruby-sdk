# frozen_string_literal: true

require "dpay/testing"

RSpec.describe "DPay BLIK" do
  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "test_service", secret_hash: "sekret-hash-123", http_client: transport) }
  let(:service) { DPay::BlikService.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  describe DPay::BlikAliasRegistration do
    it "serializes label and type" do
      expect(described_class.new("Moj alias").to_h).to eq({ "label" => "Moj alias", "type" => "UID" })
    end

    it "rejects an empty label" do
      expect { described_class.new("") }.to raise_error(DPay::InvalidArgumentError)
    end

    it "accepts only UID aliases (recurring payments go through client.recurring)" do
      expect { described_class.new("Moj alias", "PAYID") }
        .to raise_error(DPay::InvalidArgumentError, 'Invalid BLIK alias type "PAYID"')
    end
  end

  describe DPay::BlikService do
    it "registers an alias with the secret_second checksum" do
      transport.queue_json(200, { "data" => { "alias_value" => "a-1", "alias_type" => "UID", "status" => "ACTIVE",
                                              "apps" => [{ "key" => "app", "label" => "App" }] } })

      result = service.alias("a-1")

      body = transport.last_request_body
      expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/payments/blik/aliases")
      expect(body.keys).to eq(%w[service alias_value alias_type checksum])
      expect(body["checksum"]).to eq("13a2af56c258e301bba69ef61a79a6242f23f9ff58cfb231d7d0eef6732b7a4f")
      expect(result).to be_active
      expect(result.apps.first.label).to eq("App")
    end

    it "unregisters an alias and keeps reason out of the checksum" do
      transport.queue_json(200, { "data" => {} })

      expect(service.unregister_alias("a-1", DPay::BlikAliasType::UID, "rezygnacja")).to be_nil

      body = transport.last_request_body
      expect(body.keys).to eq(%w[service alias_value alias_type reason checksum])
      expect(body["checksum"]).to eq("13a2af56c258e301bba69ef61a79a6242f23f9ff58cfb231d7d0eef6732b7a4f")
    end

    it "validates the alias type" do
      expect { service.alias("a-1", "NOPE") }.to raise_error(DPay::InvalidArgumentError)
      expect { service.unregister_alias("a-1", "PAYID") }.to raise_error(DPay::InvalidArgumentError)
    end

    it "no longer exposes the removed recurring status endpoint" do
      expect(service).not_to respond_to(:recurring_status)
    end
  end
end
