# frozen_string_literal: true

# ServerTrim must remove exactly what Laravel 13 Str::trim() removes (the panel API's global TrimStrings); the PHP
# SDK test checks the same set against Laravel's regex over every code point.
RSpec.describe DPay::Internal::ServerTrim do
  it "has the 65 code points of Str::trim" do
    expect(described_class::CODE_POINTS.size).to eq(65)
    expect(described_class::CODE_POINTS.uniq).to eq(described_class::CODE_POINTS)
    expect(described_class::CODE_POINTS).to eq(described_class::CODE_POINTS.sort)
  end

  it "trims every code point of the set from both ends and keeps it inside" do
    described_class::CODE_POINTS.each do |code_point|
      character = [code_point].pack("U")
      label = format("U+%04X", code_point)

      expect(described_class.trim("#{character}a#{character}b#{character}")).to eq("a#{character}b"), label
      expect(described_class.trim(character * 2)).to eq(""), label
    end
  end

  it "trims the vectors like Laravel" do
    {
      " \t\n\r\v\f\0RET-1 \n" => "RET-1",
      "30\n" => "30",
      " 　reklamacja " => "reklamacja",
      "﻿​zwrot­\u{E0020}" => "zwrot",
      " a  b c​" => "a  b c",
      "\u0008᠏⁦x⁩￼" => "\u0008᠏⁦x⁩￼",
      "　 ﻿" => "",
      "" => "",
      " żółć " => "żółć"
    }.each do |input, expected|
      expect(described_class.trim(input)).to eq(expected), input.inspect
    end
  end

  it "differs from String#strip" do
    expect(" x​".strip).to eq(" x​")
    expect(described_class.trim(" x​")).to eq("x")
  end

  it "returns invalid UTF-8 unchanged and reads binary and other encodings as the JSON encoder does" do
    invalid = " \xC3\x28 ".b
    expect(described_class.trim(invalid)).to equal(invalid)
    expect(described_class.trim("  zwrot\n".b)).to eq("zwrot")
    expect(described_class.trim("  zwrot\n".encode(Encoding::ISO_8859_2))).to eq("zwrot")
    expect(described_class.trim("zwrot".encode(Encoding::ISO_8859_2)).encoding).to eq(Encoding::ISO_8859_2)
  end

  it "trims the strings of nested hashes and arrays and keeps other values" do
    input = { "a" => " x ", "n" => 1, "b" => true, "z" => nil,
              "w" => { "url" => "https://e.x​", "events" => ["\ty"] } }

    expect(described_class.trim_strings(input))
      .to eq({ "a" => "x", "n" => 1, "b" => true, "z" => nil, "w" => { "url" => "https://e.x", "events" => ["y"] } })
    expect(described_class.trim_strings(input).keys).to eq(%w[a n b z w])
  end

  it "requires a non-blank string" do
    expect(described_class.required(" abc\n", "transaction_id")).to eq("abc")
    expect { described_class.required("　﻿", "transaction_id") }
      .to raise_error(DPay::InvalidArgumentError, "transaction_id must not be empty")
    expect { described_class.required(42, "transaction_id") }
      .to raise_error(DPay::InvalidArgumentError, "transaction_id must be a string")
  end
end
