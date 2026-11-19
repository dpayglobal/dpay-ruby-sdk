# frozen_string_literal: true

require "json"

# Checksum and webhook vectors shared by all dpay SDKs (spec/fixtures/api_vectors.json - synthetic data computed
# with the API code, identical to tests/Fixtures/api_vectors.json of the PHP SDK).
module ApiVectors
  module_function

  def data
    @data ||= JSON.parse(File.read(File.expand_path("../fixtures/api_vectors.json", __dir__), encoding: "UTF-8"))
  end

  def webhook
    data.fetch("webhook")
  end

  # IPN payloads as dpay sends them (signature included), signed with secret_hash, with the body encoded like the
  # PHP SDK test support (JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE).
  def ipn
    data.fetch("ipn").map do |vector|
      { "name" => vector.fetch("name"), "body" => JSON.generate(vector.fetch("payload")),
        "payload" => vector.fetch("payload") }
    end
  end
end
