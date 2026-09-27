# frozen_string_literal: true

require "openssl"

RSpec.describe DPay::WebhookVerifier do
  let(:vector) { ApiVectors.webhook }
  let(:timestamp) { vector["timestamp"] }

  def headers(signature = vector["signature"])
    { "Webhook-Id" => vector["id"], "WEBHOOK-TIMESTAMP" => timestamp.to_s, "webhook-signature" => signature }
  end

  def verify(headers, secrets = vector["secret"], now = timestamp)
    described_class.verify(vector["body"], headers, secrets, 300, now)
  end

  it "verifies the signature and returns the event" do
    event = described_class.construct_event(vector["body"], headers, vector["secret"], 300, timestamp + 10)

    expect(event).to be_a(DPay::WebhookEvent)
    expect(event.id).to eq(vector["id"])
    expect(event.type).to eq("payment.succeeded")
    expect(event.object_type).to eq("payment")
    expect(event.object["amount"]).to eq(1000)
    expect(event).to be_livemode
  end

  it "accepts header values as lists and the secret without the prefix" do
    list_headers = headers.transform_values { |value| [value] }

    expect(verify(list_headers, vector["secret"].delete_prefix("whsec_"))).to be_nil
  end

  it "reads the headers with Symbol keys and in the Rack format" do
    symbols = { webhook_id: vector["id"], webhook_timestamp: timestamp.to_s, webhook_signature: vector["signature"] }
    rack = { "HTTP_WEBHOOK_ID" => vector["id"], "HTTP_WEBHOOK_TIMESTAMP" => timestamp.to_s,
             "HTTP_WEBHOOK_SIGNATURE" => vector["signature"], "rack.input" => Object.new }

    expect(verify(symbols)).to be_nil
    expect(verify(rack)).to be_nil
  end

  it "accepts either signature during a rotation" do
    # Only the old secret on the receiving side, the header carries two signatures
    expect(verify(headers(vector["rotation_signature"]), vector["old_secret"])).to be_nil
    # Both secrets on the receiving side
    expect(verify(headers, [vector["old_secret"], vector["secret"]])).to be_nil
  end

  it "rejects a tampered body" do
    expect do
      described_class.verify(vector["body"].sub("1000", "100000"), headers, vector["secret"], 300, timestamp)
    end.to raise_error(DPay::SignatureVerificationError, "No valid webhook signature found")
  end

  it "rejects a timestamp outside the tolerance" do
    expect { verify(headers, vector["secret"], timestamp + 301) }
      .to raise_error(DPay::SignatureVerificationError, /tolerance/)
    expect { verify(headers, vector["secret"], timestamp - 301) }
      .to raise_error(DPay::SignatureVerificationError, /tolerance/)
    expect(described_class.verify(vector["body"], headers, vector["secret"], 600, timestamp + 599)).to be_nil
  end

  it "uses the current time by default" do
    now = Time.now.to_i
    key = vector["secret"].delete_prefix("whsec_").unpack1("m0")
    signature = OpenSSL::HMAC.base64digest("SHA256", key, "#{vector["id"]}.#{now}.#{vector["body"]}")
    fresh = { "webhook-id" => vector["id"], "webhook-timestamp" => now.to_s, "webhook-signature" => "v1,#{signature}" }

    expect(described_class.construct_event(vector["body"], fresh, vector["secret"]).id).to eq(vector["id"])
    expect { described_class.verify(vector["body"], headers, vector["secret"]) }
      .to raise_error(DPay::SignatureVerificationError, /tolerance/)
  end

  it "rejects missing headers and a malformed timestamp" do
    expect { verify(headers.except("webhook-signature")) }
      .to raise_error(DPay::SignatureVerificationError, /Missing webhook-id/)
    expect { verify(headers.merge("webhook-signature" => "")) }
      .to raise_error(DPay::SignatureVerificationError, /Missing webhook-id/)
    expect { verify(headers.merge("WEBHOOK-TIMESTAMP" => "17905e3")) }
      .to raise_error(DPay::SignatureVerificationError, "Invalid webhook-timestamp header")
  end

  it "ignores signatures of other versions" do
    expect { verify(headers("v2,#{vector["signature"].delete_prefix("v1,")}")) }
      .to raise_error(DPay::SignatureVerificationError, "No valid webhook signature found")
  end

  it "rejects a signature made with another secret" do
    expect { verify(headers, vector["old_secret"]) }
      .to raise_error(DPay::SignatureVerificationError, "No valid webhook signature found")
  end

  it "rejects a secret that is not base64 as a configuration error" do
    ["whsec_***", "whsec_", "whsec_YQ=", nil].each do |secret|
      expect { verify(headers, secret) }.to raise_error(DPay::InvalidArgumentError, /whsec_/)
    end
  end

  it "decodes the secret like the PHP SDK (missing padding and whitespace)" do
    expect(verify(headers, vector["secret"].delete("="))).to be_nil
    expect(verify(headers, "#{vector["secret"]}\n")).to be_nil
  end

  it "verifies the official Standard Webhooks test vector" do
    official = { "webhook-id" => "msg_p5jXN8AQM9LWM0D4loKWxJek", "webhook-timestamp" => "1614265330",
                 "webhook-signature" => "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE=" }

    expect(
      described_class.verify('{"test": 2432232314}', official, "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw", 300,
                             1_614_265_330)
    ).to be_nil
  end

  it "rejects a signed body that is not a JSON object" do
    key = vector["secret"].delete_prefix("whsec_").unpack1("m0")
    signature = OpenSSL::HMAC.base64digest("SHA256", key, "#{vector["id"]}.#{timestamp}.[1,2]")

    expect { described_class.construct_event("[1,2]", headers("v1,#{signature}"), vector["secret"], 300, timestamp) }
      .to raise_error(DPay::SignatureVerificationError, "Invalid webhook payload")
  end
end
