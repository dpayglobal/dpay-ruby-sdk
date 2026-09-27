# frozen_string_literal: true

RSpec.describe DPay::RecurringRegistration do
  let(:terms) { "https://shop.example/terms" }

  def model_a
    described_class.create("Abonament", described_class::MODEL_A, terms)
                   .with_frequency("1M")
                   .with_limit_amt(5999)
                   .with_tot_limit_amt(71_988)
                   .with_expiration_date("2027-09-30")
  end

  it "sends no frequency or limits in model O" do
    registration = described_class.create("Abonament", described_class::MODEL_O, terms)
                                  .with_alias("SUB-0001")
                                  .with_methods([described_class::METHOD_BLIK])
                                  .with_terms_version("2026-09")

    expect(registration.to_h).to eq(
      { "label" => "Abonament", "alias" => "SUB-0001", "model" => "O", "methods" => ["blik"],
        "terms_url" => terms, "terms_version" => "2026-09" }
    )
    expect(registration.model).to eq("O")
  end

  it "rejects limits in model O when the body is built" do
    registration = described_class.create("Abonament", described_class::MODEL_O, terms).with_frequency("1M")

    expect { registration.to_h }
      .to raise_error(DPay::InvalidArgumentError, "frequency is not allowed in recurring model O")
  end

  it "requires the full terms in model A" do
    expect(model_a.with_init_date("2026-11-01").to_h.keys).to eq(
      %w[label model frequency limit_amt tot_limit_amt expiration_date init_date terms_url]
    )
    expect { model_a.to_h }.to raise_error(DPay::InvalidArgumentError, "init_date is required in recurring model A")
    expect { model_a.with_init_date("2026-11-01").with_limit_amt_fixed(false).to_h }
      .to raise_error(DPay::InvalidArgumentError, /fixed amount/)
  end

  it "keeps the protocol key order with every field" do
    registration = described_class.create("Subskrypcja", described_class::MODEL_M, terms)
                                  .with_terms_version("2026-09")
                                  .with_methods(["blik"])
                                  .with_init_date("2026-08-01")
                                  .with_expiration_date("2027-01-01")
                                  .with_limit_amt_fixed(true)
                                  .with_tot_limit_amt(500_000)
                                  .with_limit_amt(100_000)
                                  .with_frequency("12M")
                                  .with_alias("SUB-1")

    expect(registration.to_h.keys).to eq(
      %w[label alias model frequency limit_amt tot_limit_amt is_limit_amt_fixed expiration_date init_date methods
         terms_url terms_version]
    )
  end

  it "rejects a quarterly frequency, which BLIK does not know" do
    expect { described_class.create("Abonament", described_class::MODEL_M, terms).with_frequency("1Q") }
      .to raise_error(DPay::InvalidArgumentError)
    expect { described_class.create("Abonament", described_class::MODEL_M, terms).with_frequency("0M") }
      .to raise_error(DPay::InvalidArgumentError)
  end

  it "validates the constructor arguments" do
    expect { described_class.create("Abonament", described_class::MODEL_O, "not a url") }
      .to raise_error(DPay::InvalidArgumentError, /terms URL/)
    expect { described_class.create("", described_class::MODEL_O, terms) }.to raise_error(DPay::InvalidArgumentError)
    expect { described_class.create("x" * 51, described_class::MODEL_O, terms) }
      .to raise_error(DPay::InvalidArgumentError)
    expect { described_class.create("Abonament", "B", terms) }
      .to raise_error(DPay::InvalidArgumentError, 'Invalid recurring model "B"')
  end

  it "validates the optional terms" do
    registration = described_class.create("Abonament", described_class::MODEL_M, terms)

    expect { registration.with_alias("") }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_alias("a" * 129) }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_methods([]) }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_methods(%w[blik blik]) }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_methods(["card"]) }
      .to raise_error(DPay::InvalidArgumentError, 'Unsupported recurring method "card"')
    expect { registration.with_limit_amt(0) }.to raise_error(DPay::InvalidArgumentError, /limit_amt/)
    expect { registration.with_tot_limit_amt(DPay::Money.pln(100)) }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_init_date("2026/08/01") }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_expiration_date("01-08-2026") }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_limit_amt_fixed("true") }.to raise_error(DPay::InvalidArgumentError)
    expect { registration.with_terms_version("v" * 65) }.to raise_error(DPay::InvalidArgumentError)
  end
end
