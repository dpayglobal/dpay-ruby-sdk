# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::PayoutService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) { DPay::Config.new(service: "test_service", secret_hash: "sekret-hash-123", http_client: transport) }

  it "fetches payout details with the ordered body checksum" do
    transport.queue_json(200, { "id" => 4242, "state" => 1, "net" => 100.0, "fee" => 2.5, "gross" => 102.5,
                                "direct_settlement" => 1, "nrb" => "PL61",
                                "receiver" => { "nrb" => "PL62", "title" => "Wyplata", "amount" => 100.0 } })

    details = service.details(4242)

    body = transport.last_request_body
    expect(transport.last_request.url).to eq("https://panel.dpay.pl/api/v1/pbl/withdraws/details")
    expect(body.keys).to eq(%w[service withdraw_id checksum])
    expect(body["checksum"]).to eq("6aab621e53863b13044a361abbba01d9fb3ec7b5b834bb48a844d0507047ac15")
    expect(details.id).to eq(4242)
    expect(details).to be_processed
    expect(details).to be_direct_settlement
    expect(details.gross).to eq(DPay::Money.pln(10_250))
    expect(details.receiver.title).to eq("Wyplata")
    expect(details.receiver.amount).to eq(DPay::Money.pln(10_000))
  end

  it "includes the timestamp before the withdraw id when provided" do
    transport.queue_json(200, { "id" => 4242, "state" => 0 })

    service.details(4242, 1_784_700_000)

    body = transport.last_request_body
    expect(body.keys).to eq(%w[service timestamp withdraw_id checksum])
    expect(body["checksum"]).to eq("0604dafff2dd557e5eaac2bfbe47969a210595f66711cc3bfad729f03c24abd7")
  end

  it "raises when the envelope carries no payout id" do
    transport.queue_json(200, { "error" => true, "message" => "Not found" })

    expect { service.details(1) }.to raise_error(DPay::ApiServerError, /payout/i)
  end

  it "maps payout states" do
    transport.queue_json(200, { "id" => 1, "state" => -1, "declined" => 1, "decline_reason" => "bad iban" })

    details = service.details(1)

    expect(details).to be_failed
    expect(details).to be_declined
    expect(details.decline_reason).to eq("bad iban")
  end

  it "rejects an envelope whose payout id is zero or unparseable" do
    transport.queue_json(200, { "id" => 0, "state" => 1 })
    expect { service.details(1) }.to raise_error(DPay::ApiServerError)

    transport.queue_json(200, { "id" => "N/A", "state" => 1 })
    expect { service.details(1) }.to raise_error(DPay::ApiServerError)
  end

  it "reports no state when the API sent none" do
    transport.queue_json(200, { "id" => 4242 })

    details = service.details(4242)

    expect(details.state).to be_nil
    expect(details).not_to be_waiting
    expect(details).not_to be_processed
    expect(details).not_to be_failed
  end

  it "reports a waiting payout" do
    transport.queue_json(200, { "id" => 4242, "state" => 0 })

    expect(service.details(4242)).to be_waiting
  end
end
