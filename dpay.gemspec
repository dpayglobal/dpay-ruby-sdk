# frozen_string_literal: true

require_relative "lib/dpay/version"

Gem::Specification.new do |spec|
  spec.name = "dpay"
  spec.version = DPay::VERSION
  spec.authors = ["dpay"]
  spec.email = ["info@dpay.pl"]

  spec.summary = "Official dpay.pl Ruby SDK"
  spec.description = "Ruby client for the dpay.pl payments API: payments, recurring payments, refunds, banks, BLIK, " \
                     "cards, payouts and webhooks."
  spec.homepage = "https://dpay.pl"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dpayglobal/dpay-ruby-sdk"
  spec.metadata["changelog_uri"] = "https://github.com/dpayglobal/dpay-ruby-sdk/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]
end
