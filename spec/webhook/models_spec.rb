# frozen_string_literal: true

RSpec.describe "DPay webhook models" do
  describe DPay::WebhookTarget do
    it "serializes the URL first and the events only when given" do
      expect(described_class.create("https://shop.test/webhooks").to_h).to eq({ "url" => "https://shop.test/webhooks" })
      expect(described_class.create("https://shop.test/webhooks", ["payment.failed"]).to_h)
        .to eq({ "url" => "https://shop.test/webhooks", "events" => ["payment.failed"] })
    end

    it "requires an https URL of at most 500 characters" do
      expect { described_class.create("http://shop.test/webhooks") }.to raise_error(DPay::InvalidArgumentError, /https/)
      expect { described_class.create("https://#{"a" * 493}") }.to raise_error(DPay::InvalidArgumentError, /500/)
      expect(described_class.create("HTTPS://shop.test/webhooks").url).to eq("HTTPS://shop.test/webhooks")
    end

    it "accepts only distinct merchant events" do
      expect { described_class.create("https://shop.test/webhooks", %w[payment.failed payment.failed]) }
        .to raise_error(DPay::InvalidArgumentError, /distinct/)
      expect { described_class.create("https://shop.test/webhooks", ["merchant.updated"]) }
        .to raise_error(DPay::InvalidArgumentError, /not allowed in the webhook object of a request/)
    end

    it "checks the events against the list of the request" do
      target = described_class.create("https://shop.test/webhooks", ["payout.paid"])

      expect { target.assert_events_allowed(DPay::WebhookEventType::PAYMENT_REGISTRATION, "a payment registration") }
        .to raise_error(DPay::InvalidArgumentError, /payment registration/)
      expect(target.assert_events_allowed(DPay::WebhookEventType::MERCHANT, "a request")).to be_nil
    end
  end

  describe DPay::WebhookEvent do
    it "reads the envelope" do
      object = { "object" => "recurring_payment", "alias" => "SUB-1", "canceled_by" => "merchant" }
      event = described_class.from_api(
        { "id" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6a", "type" => "recurring_payment.canceled",
          "created" => "2026-09-27T10:06:00Z", "livemode" => false, "service" => nil, "merchant_ref" => "m-7",
          "data" => { "object" => object } }
      )

      expect(event.id).to eq("evt_01k6a8q2m4pz7h8c3v5n9t2x6a")
      expect(event.type).to eq("recurring_payment.canceled")
      expect(event.api_version).to be_nil
      expect(event.created).to eq("2026-09-27T10:06:00Z")
      expect(event).not_to be_livemode
      expect(event.service).to be_nil
      expect(event.merchant_ref).to eq("m-7")
      expect(event.object_type).to eq("recurring_payment")
      expect(event.object["canceled_by"]).to eq("merchant")
    end

    it "tolerates a malformed envelope" do
      [{ "id" => 5, "data" => { "object" => "nope" } }, {}, { "data" => { "object" => [] } }].each do |data|
        event = described_class.from_api(data)

        expect(event.id).to eq("")
        expect(event.type).to eq("")
        expect(event).to be_livemode
        expect(event.object).to eq({})
        expect(event.object_type).to be_nil
      end
    end
  end

  describe DPay::EventPage do
    it "keeps only object entries and a string cursor" do
      page = described_class.from_api(
        { "data" => [{ "id" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6y" }, "nope"], "has_more" => "yes",
          "next_starting_after" => 7 }
      )

      expect(page.data.map(&:id)).to eq(["evt_01k6a8q2m4pz7h8c3v5n9t2x6y"])
      expect(page).not_to have_more
      expect(page.next_starting_after).to be_nil
    end
  end
end
