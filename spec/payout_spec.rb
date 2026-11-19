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

  context "with the MyShop credentials" do
    let(:config) { DPay::Config.new(service: "MyShop", secret_hash: "secret123", http_client: transport) }
    let(:empty_page) do
      { "withdraws" => [], "meta" => { "page" => 1, "per_page" => 50, "total" => 0, "total_pages" => 0 } }
    end

    let(:full_details) do
      transport.queue_json(200, {
                             "settlement" => { "id" => 12_345, "state" => 1, "net" => "27.15", "fee" => "3.06",
                                               "gross" => "30.21", "currency_code" => "PLN",
                                               "creation_date" => "2026-08-01 10:00:00",
                                               "export_date" => "2026-08-01 14:20:00", "direct_settlement" => 0,
                                               "declined" => 0, "paysafecard" => 0,
                                               "nrb" => "PL61109010140000071219812874" },
                             "summary" => { "net" => "27.15", "fee" => "3.06", "gross" => "30.21", "count" => 3 },
                             "transactions" => [{ "payment_id" => "8F2C1A90-5B7E-4C31-9A02-7D6E4B1F3C88",
                                                  "date" => "2026-07-31 12:04:11", "net" => "9.05", "fee" => "1.02",
                                                  "gross" => "10.07", "service_id" => 42,
                                                  "service_name" => "Sklep testowy", "custom" => "order-1234",
                                                  "ipksef" => nil }],
                             "meta" => { "page" => 1, "per_page" => 1, "total" => 3, "total_pages" => 3 }
                           })

      service.details_full(12_345, 1, 1)
    end

    let(:list_page) do
      transport.queue_json(200, {
                             "withdraws" => [{ "id" => 12_345, "type" => "standard", "state" => 1, "net" => "27.15",
                                               "fee" => "3.06", "gross" => "30.21", "currency_code" => "EUR",
                                               "creation_date" => "2026-08-01 10:00:00",
                                               "export_date" => "2026-08-01 14:20:00", "declined" => 0 }],
                             "meta" => { "page" => 2, "per_page" => 10, "total" => 11, "total_pages" => 2 }
                           })

      service.list(
        { type: DPay::PayoutType::STANDARD, state: DPay::PayoutState::PROCESSED, date_to: "2026-08-31 23:59:59",
          date_from: "2026-08-01" }, 2, 10
      )
    end

    it "reads the currency, export date and paysafecard flag of a regular payout" do
      transport.queue_json(200, { "id" => 12_346, "state" => 0, "net" => 5.0, "fee" => 0.5, "gross" => 5.5,
                                  "creation_date" => "2026-07-01 10:00:00", "direct_settlement" => 0,
                                  "paysafecard" => 1, "nrb" => "PL61109010140000071219812874", "declined" => 0 })

      details = service.details(12_346)

      expect(details).to be_paysafecard
      expect(details).to be_waiting
      expect(details.currency).to eq("PLN")
      expect(details.export_date).to be_nil
    end

    it "sends the list filters in checksum order" do
      list_page
      body = transport.last_request_body
      expect(transport.last_request.url).to eq("https://panel.dpay.pl/api/v1/pbl/withdraws")
      expect(body.keys).to eq(%w[service date_from date_to state type page per_page checksum])
      expect(body["state"]).to eq(1)
      expect(body["checksum"])
        .to eq(Digest::SHA256.hexdigest("MyShop|2026-08-01|2026-08-31 23:59:59|1|standard|2|10|secret123"))
      expect(body["checksum"]).to eq("5be864bc1b81a002fe134dbaed5db1d6517db76fdc952842b756da253ceb504b")
    end

    it "reads the payout list page" do
      page = list_page
      item = page.items.first
      expect(page.items.size).to eq(1)
      expect(item.id).to eq(12_345)
      expect(item.type).to eq(DPay::PayoutType::STANDARD)
      expect(item).to be_processed
      expect(item).not_to be_declined
      expect(item.net).to eq(DPay::Money.of(2715, "EUR"))
      expect(item.fee).to eq(DPay::Money.of(306, "EUR"))
      expect(item.gross).to eq(DPay::Money.of(3021, "EUR"))
      expect(item.currency).to eq("EUR")
      expect(item.export_date).to eq("2026-08-01 14:20:00")
    end

    it "reads the page meta of the payout list" do
      page = list_page

      expect(page.items.first.creation_date).to eq("2026-08-01 10:00:00")
      expect(page.meta.page).to eq(2)
      expect(page.meta.total).to eq(11)
      expect(page).not_to have_more
    end

    it "signs only the service of a minimal list" do
      transport.queue_json(200, empty_page)

      page = service.list

      body = transport.last_request_body
      expect(body.keys).to eq(%w[service checksum])
      expect(body["checksum"]).to eq(Digest::SHA256.hexdigest("MyShop|secret123"))
      expect(page.items).to eq([])
      expect(page).not_to have_more
    end

    it "signs the failed state as -1" do
      transport.queue_json(200, empty_page)

      service.list({ "state" => DPay::PayoutState::FAILED })

      expect(transport.last_request_body["checksum"]).to eq(Digest::SHA256.hexdigest("MyShop|-1|secret123"))
    end

    it "sends the date filters trimmed because the API trims them before the checksum" do
      transport.queue_json(200, empty_page)

      service.list({ "date_from" => " 2026-08-01\n", "date_to" => "2026-08-31 23:59:59 " })

      body = transport.last_request_body
      expect(body["date_from"]).to eq("2026-08-01")
      expect(body["date_to"]).to eq("2026-08-31 23:59:59")
      expect(body["checksum"]).to eq(Digest::SHA256.hexdigest("MyShop|2026-08-01|2026-08-31 23:59:59|secret123"))
    end

    it "iterates over all pages" do
      row = lambda do |id|
        { "id" => id, "type" => "direct", "state" => 0, "net" => "1.00", "fee" => "0.00", "gross" => "1.00",
          "currency_code" => "PLN", "declined" => 0 }
      end
      transport.queue_json(200, { "withdraws" => [row.call(3), row.call(2)],
                                  "meta" => { "page" => 1, "per_page" => 2, "total" => 3, "total_pages" => 2 } })
      transport.queue_json(200, { "withdraws" => [row.call(1)],
                                  "meta" => { "page" => 2, "per_page" => 2, "total" => 3, "total_pages" => 2 } })

      ids = service.iterate({ type: DPay::PayoutType::DIRECT }, 2).map(&:id)

      expect(ids).to eq([3, 2, 1])
      expect(transport.requests.size).to eq(2)
      expect(transport.last_request_body["page"]).to eq(2)
      expect(transport.last_request_body["per_page"]).to eq(2)
    end

    it "stops iterating at an empty page even when the meta says there is more" do
      transport.queue_json(200, { "withdraws" => [],
                                  "meta" => { "page" => 1, "per_page" => 2, "total" => 3, "total_pages" => 2 } })

      expect(service.iterate.to_a).to eq([])
      expect(transport.requests.size).to eq(1)
    end

    it "validates the list arguments before sending" do
      [
        [{ state: 2 }, nil, nil], [{ state: "1" }, nil, nil], [{ type: "instant" }, nil, nil],
        [{ date_from: " " }, nil, nil], [{ date_to: 20_260_801 }, nil, nil], [{}, 0, nil], [{}, nil, 201],
        [{}, nil, 0], [{}, "1", nil]
      ].each do |filters, page, per_page|
        expect { service.list(filters, page, per_page) }.to raise_error(DPay::InvalidArgumentError)
      end
      expect do
        service.list({}, nil, 201)
      end.to raise_error(DPay::InvalidArgumentError, "per_page must be between 1 and 200")
      expect do
        service.list({ date_from: "\t" })
      end.to raise_error(DPay::InvalidArgumentError, "date_from must not be empty")
      expect(transport.requests).to be_empty
    end

    it "rejects unknown filters" do
      expect { service.list({ "status" => 1 }) }
        .to raise_error(DPay::InvalidArgumentError, 'Unknown payout filter "status"')
      expect { service.list({ status: 1, from: "x" }) }
        .to raise_error(DPay::InvalidArgumentError, 'Unknown payout filter "status", "from"')
    end

    it "signs the full payout details request" do
      full_details
      body = transport.last_request_body

      expect(transport.last_request.url).to eq("https://panel.dpay.pl/api/v1/pbl/withdraws/details/full")
      expect(body.keys).to eq(%w[service withdraw_id page per_page checksum])
      expect(body["checksum"]).to eq(Digest::SHA256.hexdigest("MyShop|12345|1|1|secret123"))
    end

    it "reads the header and the totals of the full payout details" do
      settlement = full_details
      header = settlement.settlement
      expect(header.id).to eq(12_345)
      expect(header).to be_processed
      expect(header).not_to be_paysafecard
      expect(header.export_date).to eq("2026-08-01 14:20:00")
      expect(header.nrb).to eq("PL61109010140000071219812874")
      expect(settlement.summary_net.minor).to eq(2715)
      expect(settlement.summary_fee.minor).to eq(306)
      expect(settlement.summary_gross.minor).to eq(3021)
      expect(settlement.summary_count).to eq(3)
      expect(settlement.meta).to have_more
    end

    it "reads the positions of the full payout details" do
      settlement = full_details
      position = settlement.positions.first
      expect(settlement.positions.size).to eq(1)
      expect(position.payment_id).to eq("8F2C1A90-5B7E-4C31-9A02-7D6E4B1F3C88")
      expect(position.date).to eq("2026-07-31 12:04:11")
      expect([position.net.minor, position.fee.minor, position.gross.minor]).to eq([905, 102, 1007])
      expect(position.service_id).to eq(42)
      expect(position.service_name).to eq("Sklep testowy")
      expect(position.custom).to eq("order-1234")
      expect(position.ipksef).to be_nil
    end

    it "reads the full details of a foreign currency payout with a minimal body" do
      transport.queue_json(200, {
                             "settlement" => { "id" => 7, "state" => 0, "net" => "10.00", "fee" => "0.00",
                                               "gross" => "10.00", "currency_code" => "EUR", "direct_settlement" => 1,
                                               "declined" => 0,
                                               "receiver" => { "nrb" => "PL61109010140000071219812874",
                                                               "title" => "FV 1", "receiverName" => "Firma",
                                                               "receiverAddress" => "Lisboa", "amount" => "10.00" } },
                             "summary" => { "net" => "10.00", "fee" => "0.00", "gross" => "10.00", "count" => 1 },
                             "transactions" => [{ "payment_id" => "P-1", "date" => nil, "net" => "10.00",
                                                  "fee" => "0.00", "gross" => "10.00", "service_id" => "42" }],
                             "meta" => { "page" => 1, "per_page" => 100, "total" => 1, "total_pages" => 1 }
                           })

      settlement = service.details_full(7)

      expect(transport.last_request_body.keys).to eq(%w[service withdraw_id checksum])
      expect(transport.last_request_body["checksum"]).to eq(Digest::SHA256.hexdigest("MyShop|7|secret123"))
      expect(settlement.settlement.currency).to eq("EUR")
      expect(settlement.settlement.net).to eq(DPay::Money.of(1000, "EUR"))
      expect(settlement.summary_net.currency).to eq("EUR")
      expect(settlement.positions.first.net.currency).to eq("EUR")
      expect(settlement.positions.first.service_id).to be_nil
      expect(settlement.settlement.receiver.receiver_name).to eq("Firma")
      expect(settlement.settlement.receiver.amount).to eq(DPay::Money.of(1000, "EUR"))
      expect(settlement.meta).not_to have_more
    end

    it "falls back on missing settlement data" do
      settlement = DPay::PayoutSettlement.from_api({ "summary" => { "net" => "x", "count" => "2" } })

      expect(settlement.settlement.currency).to eq("PLN")
      expect(settlement.summary_net).to eq(DPay::Money.pln(0))
      expect(settlement.summary_count).to eq(2)
      expect(settlement.positions).to eq([])
      expect(settlement.meta.page).to eq(1)
      expect(settlement.meta.total_pages).to eq(0)
      expect(DPay::PayoutListItem.from_api({ "currency_code" => "xx", "net" => nil, "id" => "7" }).net)
        .to eq(DPay::Money.pln(0))
    end

    it "validates per_page of the full details and maps a missing payout" do
      expect { service.details_full(1, nil, 501) }
        .to raise_error(DPay::InvalidArgumentError, "per_page must be between 1 and 500")

      transport.queue_json(404, { "status" => "error", "message" => "Withdraw does not exist!" })
      expect { service.details_full(999) }.to raise_error(DPay::NotFoundError)
    end
  end

  it "matches the shared payout checksum vectors" do
    vectors = ApiVectors.data["ordered_body"].to_h { |vector| [vector["name"], vector] }
    vectors_config = DPay::Config.new(service: ApiVectors.data["service"], secret_hash: ApiVectors.data["secret_hash"],
                                      http_client: transport)
    vectors_service = described_class.new(DPay::Internal::ApiRequestor.new(vectors_config, transport))
    calls = {
      "payouts_list_minimal" => -> { vectors_service.list },
      "payouts_list_all_filters" => lambda {
        vectors_service.list({ "date_from" => "2026-08-01", "date_to" => "2026-08-31 23:59:59", "state" => 1,
                               "type" => "standard" }, 2, 10)
      },
      "payouts_list_state_failed" => -> { vectors_service.list({ state: DPay::PayoutState::FAILED }) },
      "payouts_list_state_waiting_page_1" => -> { vectors_service.list({ state: DPay::PayoutState::WAITING }, 1) },
      "payouts_details_full_minimal" => -> { vectors_service.details_full(12_345) },
      "payouts_details_full_page" => -> { vectors_service.details_full(12_345, 2, 500) }
    }

    calls.each do |name, call|
      transport.queue_json(200, name.start_with?("payouts_list") ? { "withdraws" => [], "meta" => {} } : {})
      call.call
      body = transport.last_request_body
      checksum = body.delete("checksum")

      expect(body).to eq(vectors[name]["body"]), name
      expect(checksum).to eq(vectors[name]["checksum"]), name
    end
  end

  it "exposes the payout states and types" do
    expect(DPay::PayoutState::ALL).to eq([0, 1, -1])
    expect(DPay::PayoutType::ALL).to eq(%w[standard direct paysafecard])
    expect do
      DPay::PayoutState.assert_valid(true)
    end.to raise_error(DPay::InvalidArgumentError, 'Invalid payout state "true"')
    expect { DPay::PayoutType.assert_valid("x") }.to raise_error(DPay::InvalidArgumentError, 'Invalid payout type "x"')
  end
end
