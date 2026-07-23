# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::BankService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "test_service", secret_hash: "sekret-hash-123", http_client: transport) }

  it "lists all banks over GET without a checksum" do
    transport.queue_json(200, [{ "id" => "1", "name" => "Bank A", "image" => "https://img/1.png",
                                 "on_from" => 0, "on_to" => 24, "iterator" => 3, "test" => false, "type" => "pbl" }])

    banks = service.all

    expect(transport.last_request.method).to eq("GET")
    expect(transport.last_request.url).to eq("https://panel.dpay.pl/api/v1/pbl/banks")
    expect(transport.last_request.body).to be_nil
    expect(banks.size).to eq(1)
    expect(banks.first.name).to eq("Bank A")
    expect(banks.first.on_to).to eq(24)
    expect(banks.first.iterator).to eq(3)
    expect(banks.first).not_to be_test
  end

  it "lists service banks over POST with the ordered body checksum" do
    transport.queue_json(200, [])

    service.for_service(1_784_700_000)

    body = transport.last_request_body
    expect(transport.last_request.method).to eq("POST")
    expect(body.keys).to eq(%w[service timestamp checksum])
    expect(body["timestamp"]).to eq(1_784_700_000)
    expect(body["checksum"]).to eq("6438d831acc4cfb1f3bab9e749616317eee47c4d27f93a308bb686e85f87ea57")
  end

  it "defaults the timestamp to now" do
    transport.queue_json(200, [])
    allow(Time).to receive(:now).and_return(Time.at(1_784_700_000))

    service.for_service

    expect(transport.last_request_body["timestamp"]).to eq(1_784_700_000)
  end

  it "skips non object entries" do
    transport.queue_json(200, [{ "id" => "1", "name" => "Bank A" }, "garbage"])

    expect(service.all.size).to eq(1)
  end
end
