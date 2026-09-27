# frozen_string_literal: true

require "dpay/testing"

RSpec.describe DPay::EventService do
  subject(:service) { described_class.new(DPay::Internal::ApiRequestor.new(config, transport)) }

  let(:transport) { DPay::Testing::MockHttpClient.new }
  let(:config) do
    DPay::Config.new(service: "sdk-test-service", secret_hash: "sdk-test-hash-0001", http_client: transport)
  end

  def event(id, type = "payment.succeeded")
    { "id" => id, "type" => type, "api_version" => "2026-10-01", "created" => "2026-09-27T10:05:00Z",
      "livemode" => true, "service" => "sdk-test-service",
      "data" => { "object" => { "object" => "payment", "id" => "TX-1" } } }
  end

  it "signs the timestamp and sends the filters" do
    transport.queue_json(200, { "status" => "success", "data" => [event("evt_01k6a8q2m4pz7h8c3v5n9t2x6y")],
                                "has_more" => false, "next_starting_after" => nil })

    page = service.list({ types: %w[payment.succeeded refund.failed], limit: 50 }, 1_790_503_500)

    expect(transport.last_request.url).to eq("https://api-payments.dpay.pl/api/v1_0/events")
    expect(transport.last_request_body).to eq(
      {
        "service" => "sdk-test-service",
        "timestamp" => 1_790_503_500,
        "types" => %w[payment.succeeded refund.failed],
        "limit" => 50,
        # sha256(service|hash|timestamp) - filters stay out of the checksum
        "checksum" => "390cb30baacbc92bf2244d049f4b500937c6209446dd2fd79829d7975321abf0"
      }
    )
    expect(page.data.size).to eq(1)
    expect(page.data.first.type).to eq("payment.succeeded")
    expect(page).not_to have_more
    expect(page.next_starting_after).to be_nil
  end

  it "sends every filter in the protocol order and defaults the timestamp to now" do
    transport.queue_json(200, { "status" => "success", "data" => [], "has_more" => false })

    before = Time.now.to_i
    service.list(
      "limit" => 5, "starting_after" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6y", "created_to" => "2026-09-30T00:00:00Z",
      "created_from" => "2026-09-01T00:00:00Z", "types" => ["refund.failed"]
    )

    body = transport.last_request_body
    expect(body.keys).to eq(%w[service timestamp types created_from created_to starting_after limit checksum])
    expect(body["timestamp"]).to be_between(before, Time.now.to_i)
  end

  it "iterates page by page until the end" do
    transport.queue_json(200, { "status" => "success", "data" => [event("evt_01k6a8q2m4pz7h8c3v5n9t2x6y")],
                                "has_more" => true, "next_starting_after" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6y" })
    transport.queue_json(200, { "status" => "success", "data" => [event("evt_01k6a8q2m4pz7h8c3v5n9t2x6a")],
                                "has_more" => false, "next_starting_after" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6a" })

    ids = service.iterate(limit: 1).map(&:id)

    expect(ids).to eq(%w[evt_01k6a8q2m4pz7h8c3v5n9t2x6y evt_01k6a8q2m4pz7h8c3v5n9t2x6a])
    expect(transport.requests.size).to eq(2)
    expect(transport.last_request_body["starting_after"]).to eq("evt_01k6a8q2m4pz7h8c3v5n9t2x6y")
  end

  it "yields the events to a block" do
    transport.queue_json(200, { "status" => "success", "data" => [event("evt_01k6a8q2m4pz7h8c3v5n9t2x6y")],
                                "has_more" => true, "next_starting_after" => nil })
    ids = []

    expect(service.iterate { |item| ids << item.id }).to be_nil
    expect(ids).to eq(["evt_01k6a8q2m4pz7h8c3v5n9t2x6y"])
    expect(transport.requests.size).to eq(1)
  end

  it "validates the filters before calling the API" do
    [
      { types: ["merchant.updated"] }, { types: [] }, { types: %w[payout.paid payout.paid] },
      { starting_after: "evt_1" }, { limit: 0 }, { limit: 101 }, { limit: "10" }
    ].each do |params|
      expect { service.list(params, 1_790_503_500) }.to raise_error(DPay::InvalidArgumentError)
    end
    expect { service.list({}, "1790503500") }.to raise_error(DPay::InvalidArgumentError, /timestamp/)
    expect(transport.requests).to be_empty
  end
end
