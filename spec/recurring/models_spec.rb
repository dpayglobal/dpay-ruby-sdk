# frozen_string_literal: true

RSpec.describe "DPay recurring models" do
  describe DPay::RecurringStatus do
    it "parses limits sent as digit strings and ignores other types" do
      status = described_class.from_api(
        { "alias" => "SUB-2", "status" => "UNREGISTERED",
          "registration" => { "limit_amt" => "100", "tot_limit_amt" => "1.5", "is_limit_amt_fixed" => "true" } }
      )

      expect(status).not_to be_active
      expect(status.payment_method).to be_nil
      expect(status.registration.limit_amt).to eq(100)
      expect(status.registration.tot_limit_amt).to be_nil
      expect(status.registration.limit_amt_fixed).to be_nil
      expect(status.registration.transaction_id).to be_nil
    end

    it "tolerates a malformed payload" do
      [{ "registration" => "nope", "status" => 7 }, {}].each do |data|
        status = described_class.from_api(data)

        expect(status.alias).to eq("")
        expect(status.status).to be_nil
        expect(status.registration).to be_nil
        expect(status).not_to be_active
      end
    end
  end

  describe DPay::RecurringRetryResult do
    it "tolerates a malformed payload" do
      result = described_class.from_api({ "transactionId" => 42, "retry" => "nope" })

      expect(result.transaction_id).to eq("42")
      expect(result.status).to be_nil
      expect(result.count).to be_nil
      expect(result).not_to be_pending
      expect(result).not_to be_failed
      expect(described_class.from_api({}).transaction_id).to eq("")
    end
  end
end
