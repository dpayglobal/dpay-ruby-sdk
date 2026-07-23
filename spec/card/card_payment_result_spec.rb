# frozen_string_literal: true

RSpec.describe DPay::CardPaymentResult do
  it "detects a successful payment" do
    result = described_class.from_api({ "success" => true, "message" => { "redirectType" => "SUCCESS" } })

    expect(result).to be_success
    expect(result.redirect_url).to be_nil
    expect(result.three_ds_form_html).to be_nil
  end

  it "decodes a 3DS form" do
    html = "<form id='3ds'></form>"
    result = described_class.from_api(
      { "message" => { "redirectType" => "FORM", "redirectText" => [html].pack("m0") } }
    )

    expect(result).to be_three_ds_form
    expect(result.three_ds_form_html).to eq(html)
    expect(result.redirect_url).to be_nil
  end

  it "decodes a redirect URL" do
    url = "https://acs.example/challenge"
    result = described_class.from_api(
      { "message" => { "redirectType" => "URL", "redirectText" => [url].pack("m0") } }
    )

    expect(result).to be_requires_redirect
    expect(result.redirect_url).to eq(url)
  end

  it "exposes a DCC offer" do
    result = described_class.from_api(
      { "message" => { "redirectType" => "DCC_OFFER",
                       "dccOffer" => { "currencyConversionId" => "cc-1", "originalAmount" => 29.99,
                                       "convertedAmount" => 7.15, "convertedCurrency" => "EUR",
                                       "exchangeRate" => 4.19, "declarationText" => "PSD2",
                                       "europeanEconomicArea" => true,
                                       "markup" => [{ "rate" => 0.03, "additionalInfo" => "fee" }] } } }
    )

    expect(result).to be_dcc_offer
    expect(result.dcc_offer.currency_conversion_id).to eq("cc-1")
    expect(result.dcc_offer.converted_amount).to eq(DPay::Money.of(715, "EUR"))
    expect(result.dcc_offer.exchange_rate).to eq(4.19)
    expect(result.dcc_offer).to be_european_economic_area
    expect(result.dcc_offer.markup.first.rate).to eq(0.03)
  end

  it "returns nil for undecodable redirect text" do
    result = described_class.from_api({ "message" => { "redirectType" => "URL", "redirectText" => "!!!not-base64" } })

    expect(result.redirect_url).to be_nil
  end
end
