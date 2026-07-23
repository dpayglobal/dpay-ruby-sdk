# frozen_string_literal: true

RSpec.describe DPay::Internal::Coerce do
  describe ".string" do
    it "casts strings, numbers and booleans via PHP.strval" do
      expect(described_class.string("hello")).to eq("hello")
      expect(described_class.string("")).to eq("")
      expect(described_class.string(5)).to eq("5")
      expect(described_class.string(5.5)).to eq("5.5")
      expect(described_class.string(true)).to eq("1")
      expect(described_class.string(false)).to eq("")
    end

    it "returns nil for values with no scalar representation" do
      expect(described_class.string(nil)).to be_nil
      expect(described_class.string({})).to be_nil
      expect(described_class.string([])).to be_nil
    end
  end

  describe ".money" do
    it "builds Money from Integer, Float and String amounts" do
      expect(described_class.money(500)).to eq(DPay::Money.pln(50_000))
      expect(described_class.money(12.5)).to eq(DPay::Money.pln(1250))
      expect(described_class.money("12.34")).to eq(DPay::Money.pln(1234))
    end

    it "falls back to Money.pln(0) instead of raising for unusable values" do
      expect(described_class.money(nil)).to eq(DPay::Money.pln(0))
      expect(described_class.money("abc")).to eq(DPay::Money.pln(0))
      expect(described_class.money({})).to eq(DPay::Money.pln(0))
    end
  end

  describe ".boolean" do
    it "passes booleans through" do
      expect(described_class.boolean(true)).to be(true)
      expect(described_class.boolean(false)).to be(false)
    end

    it "treats non-zero numbers as true and zero as false" do
      expect(described_class.boolean(5)).to be(true)
      expect(described_class.boolean(-3)).to be(true)
      expect(described_class.boolean(0)).to be(false)
      expect(described_class.boolean(0.0)).to be(false)
    end

    it "treats the empty string and the string zero as false, any other string as true" do
      expect(described_class.boolean("0")).to be(false)
      expect(described_class.boolean("")).to be(false)
      expect(described_class.boolean("abc")).to be(true)
      expect(described_class.boolean("false")).to be(true)
    end

    it "defaults to false for anything else" do
      expect(described_class.boolean(nil)).to be(false)
      expect(described_class.boolean({})).to be(false)
      expect(described_class.boolean([])).to be(false)
    end
  end

  describe ".integer" do
    it "converts numerics with to_i" do
      expect(described_class.integer(5)).to eq(5)
      expect(described_class.integer(5.9)).to eq(5)
      expect(described_class.integer(-5.9)).to eq(-5)
    end

    it "reads the leading numeric prefix of a string, ignoring trailing junk" do
      expect(described_class.integer("5abc")).to eq(5)
      expect(described_class.integer("  42xyz")).to eq(42)
      expect(described_class.integer("-7 apples")).to eq(-7)
    end

    it "returns 0 when there is no leading digit" do
      expect(described_class.integer("abc")).to eq(0)
      expect(described_class.integer("abc5")).to eq(0)
      expect(described_class.integer(nil)).to eq(0)
      expect(described_class.integer({})).to eq(0)
    end
  end

  describe ".optional_integer" do
    it "converts numerics with to_i" do
      expect(described_class.optional_integer(5)).to eq(5)
      expect(described_class.optional_integer(5.9)).to eq(5)
    end

    it "accepts only a fully numeric string" do
      expect(described_class.optional_integer("42")).to eq(42)
      expect(described_class.optional_integer(" 42")).to eq(42)
      expect(described_class.optional_integer("42 ")).to be_nil
    end

    it "rejects a numeric prefix, unlike integer" do
      expect(described_class.optional_integer("5abc")).to be_nil
      expect(described_class.integer("5abc")).to eq(5)
    end

    it "returns nil for missing or non-numeric values" do
      expect(described_class.optional_integer(nil)).to be_nil
      expect(described_class.optional_integer("abc")).to be_nil
      expect(described_class.optional_integer({})).to be_nil
    end
  end

  describe ".list" do
    it "keeps only the Hash elements of an Array" do
      value = [{ "a" => 1 }, "str", 2, { "b" => 2 }, nil, [1, 2]]

      expect(described_class.list(value)).to eq([{ "a" => 1 }, { "b" => 2 }])
    end

    it "returns an empty array for anything that is not an Array" do
      expect(described_class.list(nil)).to eq([])
      expect(described_class.list("nope")).to eq([])
      expect(described_class.list({})).to eq([])
    end
  end
end
