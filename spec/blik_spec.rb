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
  end

  describe DPay::BlikRecurringRegistration do
    it "serializes with PAYID and decimal value" do
      registration = described_class.create("Subskrypcja", "A", "1M")
                                    .with_value(DPay::Money.pln(2999))
                                    .with_limit_amt(5000)

      expect(registration.to_h).to eq(
        { "label" => "Subskrypcja", "type" => "PAYID", "model" => "A", "frequency" => "1M",
          "value" => "29.99", "limit_amt" => 5000 }
      )
    end

    it "validates model and frequency" do
      expect { described_class.create("x", "Z", "1M") }.to raise_error(DPay::InvalidArgumentError)
      expect { described_class.create("x", "A", "0M") }.to raise_error(DPay::InvalidArgumentError)
      expect { described_class.create("x", "A", "1M").with_init_date("01-2026") }
        .to raise_error(DPay::InvalidArgumentError)
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

    it "reads recurring status" do
      transport.queue_json(200, { "data" => { "alias_value" => "a-1", "status" => "ACTIVE",
                                              "registration" => { "model" => "A", "frequency" => "1M",
                                                                  "limit_amt" => 5000,
                                                                  "is_limit_amt_fixed" => true } } })

      status = service.recurring_status("a-1")

      expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/payments/blik/recurring/status")
      expect(status).to be_active
      expect(status.alias_type).to eq("PAYID")
      expect(status.registration.frequency).to eq("1M")
      expect(status.registration.limit_amt).to eq(5000)
      expect(status.registration.limit_amt_fixed).to be(true)
    end

    it "validates the alias type" do
      expect { service.alias("a-1", "NOPE") }.to raise_error(DPay::InvalidArgumentError)
    end
  end
end
