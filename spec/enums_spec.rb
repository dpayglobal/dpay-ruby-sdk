# frozen_string_literal: true

RSpec.describe DPay do
  describe DPay::TransactionType do
    it "exposes transaction types" do
      expect(described_class::TRANSFERS).to eq("transfers")
      expect(described_class::CARD_RECURRING).to eq("card_recurring")
      expect(described_class::ALL.size).to eq(5)
      expect(described_class::ALL).to be_frozen
    end

    it "validates known values" do
      expect(described_class.valid?("transfers")).to be(true)
      expect { described_class.assert_valid("transfers") }.not_to raise_error
    end

    it "rejects unknown values with a domain specific message" do
      expect { described_class.assert_valid("cash") }
        .to raise_error(DPay::InvalidArgumentError, 'Invalid transaction type "cash"')
    end

    it "rejects the removed types" do
      # blik_recurring: registration through recurring_registration; bizum_direct: not supported by the API
      %w[blik_recurring bizum_direct].each do |removed|
        expect { described_class.assert_valid(removed) }.to raise_error(DPay::InvalidArgumentError)
      end
      expect(described_class.const_defined?(:BLIK_RECURRING)).to be(false)
      expect(described_class.const_defined?(:BIZUM_DIRECT)).to be(false)
    end
  end

  describe DPay::WebhookEventType do
    it "exposes the event types and the per-request lists" do
      expect(described_class::MERCHANT.size).to eq(11)
      expect(described_class::PAYMENT_REGISTRATION.size).to eq(9)
      expect(described_class::REFUND).to eq(%w[refund.succeeded refund.failed])
      expect(described_class::CAPTURE).to eq(["payment.captured"])
      expect(described_class::MERCHANT).not_to include(described_class::WEBHOOK_TEST)
      expect([described_class::MERCHANT, described_class::PAYMENT_REGISTRATION]).to all(be_frozen)
    end

    it "rejects events outside the allowed list" do
      expect { described_class.assert_allowed(["payout.paid"], described_class::REFUND, "a refund") }
        .to raise_error(
          DPay::InvalidArgumentError, 'Event "payout.paid" is not allowed in the webhook object of a refund'
        )
    end
  end

  describe DPay::RecurringStatus do
    it "exposes the recurring payment statuses" do
      expect(described_class::ALL).to eq(%w[ACTIVE INACTIVE UNREGISTERED EXPIRED DECLINED])
      expect(described_class::ALL).to be_frozen
    end
  end

  describe DPay::TransactionStatus do
    it "exposes transaction status values" do
      expect(described_class::PAID).to eq("paid")
      expect(described_class::ALL).to be_frozen
    end
  end

  describe DPay::PayoutFeeMode do
    it "exposes payout fee mode values" do
      expect(described_class::GROSS).to eq("gross")
      expect(described_class::ALL).to be_frozen
    end
  end

  describe DPay::RedirectType do
    it "exposes redirect type values" do
      expect(described_class::DCC_OFFER).to eq("DCC_OFFER")
      expect(described_class::ALL).to be_frozen
    end
  end

  describe DPay::DccDecision do
    it "exposes DCC decision values" do
      expect(described_class::ACCEPT).to eq("accept")
      expect(described_class::ALL).to be_frozen
    end

    it "rejects unknown values with a domain specific message" do
      expect { described_class.assert_valid("maybe") }
        .to raise_error(DPay::InvalidArgumentError, 'Invalid DCC decision "maybe"')
    end
  end

  describe DPay::CardRecurringOperation do
    it "exposes card recurring operation values" do
      expect(described_class::COF_INITIAL).to eq("cof_initial")
      expect(described_class::ALL).to be_frozen
    end
  end

  describe DPay::CardRecurringFrequency do
    it "exposes card recurring frequency values" do
      expect(described_class::SEMIANNUAL).to eq("SEMIANNUAL")
      expect(described_class::ALL).to be_frozen
    end
  end

  describe DPay::BlikAliasType do
    it "exposes BLIK alias type values" do
      expect(described_class::UID).to eq("UID")
      expect(described_class::ALL).to be_frozen
    end

    it "rejects unknown values with a domain specific message" do
      expect { described_class.assert_valid("X") }
        .to raise_error(DPay::InvalidArgumentError, 'Invalid BLIK alias type "X"')
    end
  end

  describe DPay::IpnType do
    it "exposes IPN type values" do
      expect(described_class::DCB).to eq("dcb")
      expect(described_class::ALL).to be_frozen
    end

    it "rejects unknown values with a domain specific message" do
      expect { described_class.assert_valid("x") }
        .to raise_error(DPay::InvalidArgumentError, 'Invalid IPN type "x"')
    end
  end
end
