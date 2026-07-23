# frozen_string_literal: true

module DPay
  class BlikApp
    attr_reader :key, :label

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @key = data["key"].is_a?(String) ? data["key"] : nil
      @label = data["label"].is_a?(String) ? data["label"] : nil
      freeze
    end
  end
end
