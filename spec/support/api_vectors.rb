# frozen_string_literal: true

require "json"

# Checksum and webhook vectors shared by all dpay SDKs (spec/fixtures/api_vectors.json - synthetic data computed
# with the API code, identical to tests/Fixtures/api_vectors.json of the PHP SDK).
module ApiVectors
  module_function

  def data
    @data ||= JSON.parse(File.read(File.expand_path("../fixtures/api_vectors.json", __dir__)))
  end

  def webhook
    data.fetch("webhook")
  end
end
