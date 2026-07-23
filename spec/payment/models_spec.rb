# frozen_string_literal: true

RSpec.describe "DPay payment models" do
  describe DPay::RegisteredPayment do
    it "reads the transaction id and redirect URL" do
      payment = described_class.from_api(
        { "transactionId" => "tx-1", "msg" => "https://secure.dpay.pl/pay/1", "ipksef" => "KSEF-1" }
      )

      expect(payment.transaction_id).to eq("tx-1")
      expect(payment.redirect_url).to eq("https://secure.dpay.pl/pay/1")
      expect(payment.ipksef).to eq("KSEF-1")
      expect(payment).not_to be_paid
    end

    it "detects paid and internal processing states" do
      expect(described_class.from_api({ "msg" => "Transaction paid" })).to be_paid
      expect(described_class.from_api({ "msg" => "Internal processing" })).to be_internal_processing
      expect(described_class.from_api({ "msg" => "Transaction paid" }).redirect_url).to be_nil
    end

    it "reads the card recurring alias from additional info" do
      payment = described_class.from_api({ "additionalInfo" => { "card_recurring_alias" => "alias-1" } })

      expect(payment.card_recurring_alias).to eq("alias-1")
    end
  end

  describe DPay::Transaction do
    subject(:transaction) do
      described_class.from_api(
        "transaction" => {
          "id" => "tx-1", "value" => 29.99, "status" => "paid", "payment_method" => "blik",
          "creation_date" => "2026-07-01 10:00:00", "payment_date" => "2026-07-01 10:01:00",
          "settled" => true, "refunded" => false, "refunded_amount" => 0,
          "available_refund_amount" => 29.99, "fully_refunded" => false, "direct" => true,
          "gateway_id" => "gw-1"
        },
        "payer" => { "email" => "jan@example.com" },
        "refunds" => [{ "payment_id" => "rf-1", "value" => 5.0, "status" => "paid" }]
      )
    end

    it "maps nested transaction data" do
      expect(transaction.id).to eq("tx-1")
      expect(transaction.value).to eq(DPay::Money.pln(2999))
      expect(transaction).to be_paid
      expect(transaction).to be_settled
      expect(transaction).not_to be_refunded
      expect(transaction.available_refund_amount.to_decimal).to eq("29.99")
      expect(transaction.payer).to eq({ "email" => "jan@example.com" })
      expect(transaction.gateway_id).to eq("gw-1")
    end

    it "maps nested refunds" do
      expect(transaction.refunds.size).to eq(1)
      expect(transaction.refunds.first.payment_id).to eq("rf-1")
      expect(transaction.refunds.first.value).to eq(DPay::Money.pln(500))
    end

    it "treats captured as paid and tolerates unknown statuses" do
      expect(described_class.from_api({ "transaction" => { "status" => "captured" } })).to be_paid
      expect(described_class.from_api({ "transaction" => { "status" => "brand_new" } }).status).to eq("brand_new")
      expect(described_class.from_api({}).value).to eq(DPay::Money.pln(0))
    end
  end
end
