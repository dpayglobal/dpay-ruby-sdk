# frozen_string_literal: true

require "json"

module GoldenFixtures
  module_function

  def load(name)
    JSON.parse(File.read(File.expand_path("../golden/#{name}.json", __dir__)))
  end

  def php_sdk
    @php_sdk ||= load("php_sdk_golden")
  end
end
