# frozen_string_literal: true

RSpec.describe "DPay payment input value objects" do
  describe DPay::ReturnUrls do
    it "keeps the three URLs" do
      urls = described_class.new("https://shop.test/ok", "https://shop.test/fail", "https://shop.test/ipn")

      expect(urls.success).to eq("https://shop.test/ok")
      expect(urls.fail).to eq("https://shop.test/fail")
      expect(urls.ipn).to eq("https://shop.test/ipn")
    end

    it "rejects malformed URLs" do
      expect { described_class.new("not-a-url", "https://shop.test/fail", "https://shop.test/ipn") }
        .to raise_error(DPay::InvalidArgumentError, /success/)
    end
  end

  describe DPay::Payer do
    it "collects optional identity data" do
      payer = described_class.create.with_email("jan@example.com").with_name("Jan", "Kowalski")

      expect(payer.email).to eq("jan@example.com")
      expect(payer.first_name).to eq("Jan")
      expect(payer.last_name).to eq("Kowalski")
    end

    it "rejects a malformed email" do
      expect { described_class.create.with_email("nope") }.to raise_error(DPay::InvalidArgumentError)
    end
  end

  describe DPay::DeviceInfo do
    subject(:device_info) do
      described_class.create(
        browser_accept_header: "text/html", browser_language: "pl-PL", browser_color_depth: 24,
        browser_screen_height: 1080, browser_screen_width: 1920, browser_tz: -60,
        browser_user_agent: "Mozilla/5.0", system_family: "Windows", geo_localization: "52.2297,21.0122",
        device_id: "device-1", application_name: "shop"
      )
    end

    it "serializes wire keys in order" do
      expect(device_info.to_h.keys).to eq(
        %w[browserAcceptHeader browserLanguage browserColorDepth browserScreenHeight browserScreenWidth
           browserTZ browserUserAgent systemFamily geoLocalization deviceID applicationName]
      )
      expect(device_info.to_h["deviceID"]).to eq("device-1")
      expect(device_info.to_h["browserTZ"]).to eq(-60)
    end

    it "serializes the java flag as a string" do
      expect(device_info.with_browser_java_enabled(true).to_h["browserJavaEnabled"]).to eq("true")
      expect(device_info.with_browser_java_enabled(false).to_h["browserJavaEnabled"]).to eq("false")
    end

    it "validates identifiers" do
      expect do
        described_class.create(
          browser_accept_header: "text/html", browser_language: "pl-PL", browser_color_depth: 24,
          browser_screen_height: 1080, browser_screen_width: 1920, browser_tz: -60,
          browser_user_agent: "Mozilla/5.0", system_family: "Windows", geo_localization: "52.2297,21.0122",
          device_id: "", application_name: "shop"
        )
      end.to raise_error(DPay::InvalidArgumentError)
    end
  end

  describe DPay::InvoiceDetails do
    it "serializes only provided fields and VAT in minor units" do
      invoice = described_class.create
                               .with_payer_nip("1234567890")
                               .with_payment_due_date("2026-08-01")
                               .with_vat_amount(DPay::Money.pln(2300))

      expect(invoice.to_h).to eq(
        { "payer_nip" => "1234567890", "payment_due_date" => "2026-08-01", "vat_amount" => 2300 }
      )
    end

    it "rejects a malformed due date" do
      expect { described_class.create.with_payment_due_date("01-08-2026") }
        .to raise_error(DPay::InvalidArgumentError)
    end
  end

  describe DPay::PayoutInstruction do
    it "serializes positions with float amounts" do
      instruction = described_class.create(
        [DPay::PayoutPosition.new("PL61109010140000071219812874", "Wyplata 1", DPay::Money.pln(1050))],
        DPay::PayoutFeeMode::GROSS
      )

      expect(instruction.to_h).to eq(
        {
          "fee_mode" => "gross",
          "positions" => [
            { "iban" => "PL61109010140000071219812874", "title" => "Wyplata 1", "amount" => 10.5 }
          ]
        }
      )
    end

    it "requires at least one position" do
      expect { described_class.create([]) }.to raise_error(DPay::InvalidArgumentError)
    end
  end
end
