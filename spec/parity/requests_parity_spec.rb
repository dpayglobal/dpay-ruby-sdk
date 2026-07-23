# frozen_string_literal: true

require "dpay/testing"
require_relative "scenario"

RSpec.describe "PHP request parity" do
  let(:ignored_headers) { ["User-Agent"] }

  def flatten_leaves(value, prefix = "")
    case value
    when Hash then value.flat_map { |key, item| flatten_leaves(item, "#{prefix}.#{key}") }
    when Array then value.each_with_index.flat_map { |item, index| flatten_leaves(item, "#{prefix}[#{index}]") }
    else [[prefix, value]]
    end
  end

  def normalize(request)
    {
      "method" => request.method,
      "url" => request.url,
      "headers" => request.headers.except(*ignored_headers),
      "body" => request.body
    }
  end

  it "reproduces every recorded golden call byte for byte" do
    golden = GoldenFixtures.php_sdk["calls"]
    recorded = ParityScenario.run

    expect(recorded.size).to eq(golden.size)

    golden.each_with_index do |expected, index|
      actual = flatten_leaves(normalize(recorded[index])).to_h
      wanted = flatten_leaves(
        expected.merge("headers" => expected["headers"].except(*ignored_headers))
      )

      wanted.each do |path, value|
        expect(actual[path]).to eq(value), "call #{index} (#{expected["url"]}) mismatch at #{path}"
      end
    end
  end
end
