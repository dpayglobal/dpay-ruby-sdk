# frozen_string_literal: true

RSpec.describe DPay::Internal::ChecksumCalculator do
  subject(:calculator) { described_class.new("secret123") }

  it "matches the golden register payment checksum" do
    checksum = calculator.secret_second(
      "MyShop",
      ["10.00", "https://shop.example/ok", "https://shop.example/fail", "https://shop.example/ipn"]
    )

    expect(checksum).to eq("ae7fd11b457d6fc41edd193dfb0dd42b471bd6d312c1ae12dffeb931371c4cd2")
  end

  it "matches the golden checksum for a normalized value" do
    checksum = calculator.secret_second(
      "MyShop",
      ["1.00", "https://shop.example/ok", "https://shop.example/fail", "https://shop.example/ipn"]
    )

    expect(checksum).to eq("5c97b7209b5d28edcb3768acbcb060030830c088d1f3335ede9dc9a9f949cd05")
  end

  it "matches the golden BLIK alias checksum" do
    expect(calculator.secret_second("MyShop", ["DPAY.UID.123456.abc12345"]))
      .to eq("231f56ec6cae2209e0743a34ad2a2e38c43dd78df63cafffe69a9ea2c4fb3490")
  end

  it "matches the golden full refund ordered body checksum" do
    expect(calculator.ordered_body(%w[MyShop 30D9493D-1D73-3FBD-A5D4-633723CC7A68]))
      .to eq("3b345f55900ae6a43220dd14a3827ed9a26a02a3eb46b856d302e2baa44b48a4")
  end

  it "matches the golden partial refund ordered body checksum" do
    expect(calculator.ordered_body(["MyShop", "30D9493D-1D73-3FBD-A5D4-633723CC7A68", "15.00", "reklamacja"]))
      .to eq("5c00684addf39fda89d3d6cff88abf26bb8173119056fd3012050422943c798a")
  end

  it "casts integers through PHP semantics" do
    expect(calculator.ordered_body(["MyShop", 1_753_100_000]))
      .to eq("189d0301f163fb105c9f3d607e8fe0adbbfc5ecd8e16271a682d672f43ab623c")
    expect(calculator.ordered_body(["MyShop", 12_345]))
      .to eq("9c7f5305d2de640ed3d1915f6ca33d6040b1583fab56676d0fcdcf65765b223d")
  end

  it "is order sensitive" do
    expect(calculator.ordered_body(%w[MyShop TX-1])).not_to eq(calculator.ordered_body(%w[TX-1 MyShop]))
  end
end
