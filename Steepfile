# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig"
  check "lib"

  library "json"
  library "digest"
  library "openssl"
  library "uri"
  library "net-http"

  configure_code_diagnostics do |hash|
    hash[D::Ruby::UnannotatedEmptyCollection] = :information
  end
end
