# frozen_string_literal: true

RSpec.describe DPay::RegisterPaymentRequest do
  let(:urls) { DPay::ReturnUrls.new("https://shop.test/ok", "https://shop.test/fail", "https://shop.test/ipn") }

  def request
    described_class.create(DPay::Money.pln(2999), DPay::TransactionType::TRANSFERS, urls)
  end

  it "builds the minimal body in protocol order" do
    body = request.to_body("test_service")

    expect(body.keys).to eq(%w[service value transactionType url_success url_fail url_ipn])
    expect(body["value"]).to eq("29.99")
    expect(body["transactionType"]).to eq("transfers")
  end

  it "appends optional fields in protocol order" do
    body = request
           .with_description("Zamowienie #1234")
           .with_custom("order-1234")
           .with_payer(DPay::Payer.create.with_email("jan@example.com").with_name("Jan", "Kowalski"))
           .with_accept_tos(true)
           .with_channel("86")
           .to_body("test_service")

    expect(body.keys).to eq(
      %w[service value transactionType url_success url_fail url_ipn
         description custom email client_name client_surname accept_tos channel]
    )
  end

  it "serializes method toggles as integers" do
    body = request.with_credit_card(true).with_paysafecard(false).with_blik(true).to_body("test_service")

    expect(body["creditcard"]).to eq(1)
    expect(body["paysafecard"]).to eq(0)
    expect(body["blik"]).to eq(1)
  end

  it "validates the transaction type" do
    expect { described_class.create(DPay::Money.pln(100), "cash", urls) }
      .to raise_error(DPay::InvalidArgumentError)
  end

  it "validates BLIK inputs and mutual exclusions" do
    expect { request.with_blik_code("12345", "UA", "1.2.3.4") }.to raise_error(DPay::InvalidArgumentError)
    expect { request.with_blik_code("123456", "UA", "1.2.3.4").with_blik_alias("a-1", "UA", "1.2.3.4") }
      .to raise_error(DPay::InvalidArgumentError, /cannot be combined/)
    expect { request.with_partner_platform("shopify") }.to raise_error(DPay::InvalidArgumentError)
  end

  it "rejects conflicting card recurring configuration" do
    registration = double(to_h: { "label" => "m" })

    expect { request.with_card_recurring_alias("alias").with_card_recurring(registration) }
      .to raise_error(DPay::InvalidArgumentError, /cannot be combined/)
  end

  it "allows efaktura only for transfers" do
    card = described_class.create(DPay::Money.pln(100), DPay::TransactionType::CARD_AUTH, urls)

    expect { card.with_efaktura }.to raise_error(DPay::InvalidArgumentError, /transfers/)
    expect(request.with_efaktura.to_body("test_service")["efaktura"]).to be(true)
  end

  it "serializes nested structures" do
    body = request
           .with_payout(DPay::PayoutInstruction.create([DPay::PayoutPosition.new("PL61", "t", DPay::Money.pln(1050))]))
           .to_body("test_service")

    expect(body["payout"]).to eq(
      { "fee_mode" => "net", "positions" => [{ "iban" => "PL61", "title" => "t", "amount" => 10.5 }] }
    )
  end
end
