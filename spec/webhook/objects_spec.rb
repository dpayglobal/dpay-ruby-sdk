# frozen_string_literal: true

# Typed data.object models of webhook events (payloads as in the webhook documentation and the API object builders).
RSpec.describe "DPay webhook objects" do
  def event(type, object)
    DPay::WebhookEvent.from_api(
      { "id" => "evt_01k6a8q2m4pz7h8c3v5n9t2x6y", "type" => type, "api_version" => "2026-10-01",
        "created" => "2026-09-27T10:05:00Z", "livemode" => true, "service" => "abc123",
        "data" => { "object" => object } }
    )
  end

  let(:succeeded) do
    event("payment.succeeded", {
            "object" => "payment", "id" => "8F2A11C4-5B6D-4E7F-8A9B-0C1D2E3F4A5B", "status" => "succeeded",
            "amount" => 14_900, "currency" => "PLN", "amount_refunded" => 0, "amount_captured" => 0,
            "description" => "Order 2026/09/123", "created" => "2026-09-27T10:03:12Z",
            "paid_at" => "2026-09-27T10:05:00Z",
            "payment_method" => { "type" => "blik", "blik" => { "flow" => "code" } }, "failure" => nil,
            "recurring" => nil, "references" => { "merchant" => "2026/09/123", "provider" => "1234567890" },
            "custom" => "order-789"
          })
  end

  it "returns only the typed object of the event kind" do
    expect(succeeded.payment).to be_a(DPay::PaymentObject)
    expect(succeeded.refund).to be_nil
    expect(succeeded.recurring_payment).to be_nil
    expect(succeeded.payout).to be_nil
  end

  it "reads a succeeded payment" do
    payment = succeeded.payment

    expect(payment.id).to eq("8F2A11C4-5B6D-4E7F-8A9B-0C1D2E3F4A5B")
    expect(payment.status).to eq(DPay::PaymentObject::STATUS_SUCCEEDED)
    expect(payment.amount).to eq(DPay::Money.pln(14_900))
    expect(payment.amount_refunded).to eq(DPay::Money.pln(0))
    expect(payment.amount_captured.minor).to eq(0)
    expect(payment.description).to eq("Order 2026/09/123")
    expect(payment.created).to eq("2026-09-27T10:03:12Z")
    expect(payment.paid_at).to eq("2026-09-27T10:05:00Z")
    expect(payment.raw["object"]).to eq("payment")
  end

  it "reads the method, references and custom value of a payment" do
    payment = succeeded.payment

    expect(payment.payment_method_type).to eq("blik")
    expect(payment.payment_method).to eq({ "type" => "blik", "blik" => { "flow" => "code" } })
    expect(payment.failure).to be_nil
    expect(payment).not_to be_recurring
    expect(payment.recurring_alias).to be_nil
    expect(payment.merchant_reference).to eq("2026/09/123")
    expect(payment.provider_reference).to eq("1234567890")
    expect(payment.custom).to eq("order-789")
  end

  it "reads a failed recurring charge in euro" do
    payment = event("payment.failed", {
                      "object" => "payment", "id" => "P-2", "status" => "failed", "amount" => 4999, "currency" => "EUR",
                      "amount_refunded" => 0, "amount_captured" => 0, "description" => nil,
                      "created" => "2026-10-01T08:00:00Z", "paid_at" => nil, "payment_method" => nil,
                      "failure" => { "code" => "insufficient_funds", "message" => "Insufficient funds",
                                     "category" => "customer", "retryable" => true,
                                     "provider_code" => "INSUFFICIENT_FUNDS" },
                      "recurring" => { "alias" => "SUB-0001", "registration" => "P-1", "sequence" => "subsequent" },
                      "references" => { "merchant" => nil, "provider" => nil }, "custom" => nil
                    }).payment
    failure = payment.failure

    expect(payment.status).to eq(DPay::PaymentObject::STATUS_FAILED)
    expect(payment.recurring_sequence).to eq(DPay::PaymentObject::SEQUENCE_SUBSEQUENT)
    expect(payment.amount).to eq(DPay::Money.of(4999, "EUR"))
    expect(payment.paid_at).to be_nil
    expect(payment).to be_recurring
    expect(payment.recurring_alias).to eq("SUB-0001")
    expect(payment.recurring_registration).to eq("P-1")
    expect(failure.code).to eq(DPay::DeclineCode::INSUFFICIENT_FUNDS)
    expect(failure.message).to eq("Insufficient funds")
    expect(failure.category).to eq(DPay::FailureCategory::CUSTOMER)
    expect(failure).to be_retryable
    expect(failure.provider_code).to eq("INSUFFICIENT_FUNDS")
  end

  it "reads a failed refund" do
    refund = event("refund.failed", {
                     "object" => "refund", "id" => nil, "payment" => "8F2A11C4-5B6D-4E7F-8A9B-0C1D2E3F4A5B",
                     "status" => "failed", "amount" => 2000, "currency" => "PLN", "created" => "2026-10-01T08:00:00Z",
                     "succeeded_at" => nil,
                     "failure" => { "code" => "refund_window_expired", "message" => "The refund period has expired",
                                    "category" => "merchant", "retryable" => false, "provider_code" => nil }
                   }).refund

    expect(refund.id).to be_nil
    expect(refund.payment).to eq("8F2A11C4-5B6D-4E7F-8A9B-0C1D2E3F4A5B")
    expect(refund.status).to eq(DPay::RefundObject::STATUS_FAILED)
    expect(refund.amount.minor).to eq(2000)
    expect(refund.currency).to eq("PLN")
    expect(refund.created).to eq("2026-10-01T08:00:00Z")
    expect(refund.succeeded_at).to be_nil
    expect(refund.failure.code).to eq(DPay::DeclineCode::REFUND_WINDOW_EXPIRED)
    expect(refund.failure.category).to eq(DPay::FailureCategory::MERCHANT)
    expect(refund.failure).not_to be_retryable
    expect(refund.failure.provider_code).to be_nil
  end

  it "reads a canceled recurring payment" do
    recurring = event("recurring_payment.canceled", {
                        "object" => "recurring_payment", "id" => "P-1", "alias" => "SUB-0001", "status" => "canceled",
                        "canceled_by" => "customer",
                        "payment_method" => { "type" => "blik", "blik" => { "flow" => "recurring" } },
                        "terms" => { "model" => "A", "frequency" => "1M", "limit_amount" => 5999,
                                     "total_limit_amount" => 71_988, "starts_on" => "2026-11-01",
                                     "expires_on" => "2027-09-30" },
                        "created" => "2026-09-26T10:00:00Z"
                      }).recurring_payment

    expect(recurring.id).to eq("P-1")
    expect(recurring.alias).to eq("SUB-0001")
    expect(recurring.status).to eq(DPay::RecurringPaymentObject::STATUS_CANCELED)
    expect(recurring.canceled_by).to eq(DPay::RecurringPaymentObject::CANCELED_BY_CUSTOMER)
    expect(recurring.payment_method_type).to eq("blik")
    expect(recurring.model).to eq("A")
    expect(recurring.frequency).to eq("1M")
    expect(recurring.limit_amount).to eq(5999)
    expect(recurring.total_limit_amount).to eq(71_988)
    expect(recurring.starts_on).to eq("2026-11-01")
    expect(recurring.expires_on).to eq("2027-09-30")
    expect(recurring.created).to eq("2026-09-26T10:00:00Z")
  end

  it "reads a model O recurring payment without limits" do
    recurring = event("recurring_payment.activated", {
                        "object" => "recurring_payment", "id" => "P-1", "alias" => "SUB-0002", "status" => "active",
                        "canceled_by" => nil, "payment_method" => nil,
                        "terms" => { "model" => "O", "frequency" => nil, "limit_amount" => nil,
                                     "total_limit_amount" => "100", "starts_on" => nil, "expires_on" => nil },
                        "created" => "2026-09-26T10:00:00Z"
                      }).recurring_payment

    expect(recurring.status).to eq(DPay::RecurringPaymentObject::STATUS_ACTIVE)
    expect(recurring.canceled_by).to be_nil
    expect(recurring.limit_amount).to be_nil
    expect(recurring.total_limit_amount).to be_nil
    expect(recurring.frequency).to be_nil
  end

  it "reads a failed payout" do
    payout = event("payout.failed", {
                     "object" => "payout", "id" => "12345", "status" => "failed", "amount" => 2715, "fee" => 306,
                     "currency" => "PLN", "bank_account" => { "last4" => "2874" }, "created" => "2026-08-01T08:00:00Z",
                     "paid_at" => nil,
                     "failure" => { "code" => "payout_failed", "message" => "The payout could not be completed",
                                    "category" => "merchant", "retryable" => false, "provider_code" => "RETURNED" }
                   }).payout

    expect(payout.id).to eq("12345")
    expect(payout.status).to eq(DPay::PayoutObject::STATUS_FAILED)
    expect(payout.amount.minor).to eq(2715)
    expect(payout.fee.minor).to eq(306)
    expect(payout.bank_account_last4).to eq("2874")
    expect(payout.created).to eq("2026-08-01T08:00:00Z")
    expect(payout.paid_at).to be_nil
    expect(payout.failure.code).to eq(DPay::DeclineCode::PAYOUT_FAILED)
    expect(payout.failure.provider_code).to eq("RETURNED")
  end

  it "has no typed object for a test event" do
    webhook = event("webhook.test", { "object" => "webhook_endpoint", "id" => "we_1" })

    expect(webhook.payment).to be_nil
    expect(webhook.refund).to be_nil
    expect(webhook.recurring_payment).to be_nil
    expect(webhook.payout).to be_nil
    expect(webhook.object_type).to eq("webhook_endpoint")
  end

  it "falls back on missing or malformed fields" do
    payment = DPay::PaymentObject.from_api(
      { "object" => "payment", "currency" => "xx", "amount" => "10.00", "failure" => { "code" => "", "retryable" => 1,
                                                                                       "provider_code" => 51 } }
    )

    expect(payment.id).to eq("")
    expect(payment.currency).to eq("PLN")
    expect(payment.amount.minor).to eq(0)
    expect(payment.failure.code).to eq(DPay::DeclineCode::GENERIC_DECLINE)
    expect(payment.failure).not_to be_retryable
    expect(payment.failure.category).to be_nil
    expect(payment.failure.provider_code).to eq("51")
    expect(DPay::PayoutObject.from_api({ "id" => 12_345 }).id).to eq("12345")
  end

  it "lists the decline codes and failure categories" do
    expect(DPay::DeclineCode::ALL.size).to eq(22)
    expect(DPay::DeclineCode::ALL.uniq).to eq(DPay::DeclineCode::ALL)
    expect(DPay::DeclineCode::ALL.first(2)).to eq(%w[insufficient_funds limit_exceeded])
    expect(DPay::DeclineCode::ALL.last).to eq("processing_error")
    expect(DPay::FailureCategory::ALL).to eq(%w[customer merchant risk system])
  end
end
