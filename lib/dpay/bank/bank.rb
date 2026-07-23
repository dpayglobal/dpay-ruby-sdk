# frozen_string_literal: true

module DPay
  class Bank
    attr_reader :id, :name, :image, :on_from, :on_to, :iterator, :type, :raw

    def self.from_api(data)
      new(data)
    end

    def initialize(data)
      @raw = data
      @id = Internal::Coerce.string(data["id"]) || ""
      @name = Internal::Coerce.string(data["name"]) || ""
      @image = data["image"].is_a?(String) ? data["image"] : nil
      @on_from = Internal::Coerce.integer(data["on_from"])
      @on_to = Internal::Coerce.integer(data["on_to"])
      @iterator = data["iterator"].nil? ? nil : Internal::Coerce.integer(data["iterator"])
      @test = Internal::Coerce.boolean(data["test"])
      @type = data["type"].is_a?(String) ? data["type"] : nil
      freeze
    end

    def test?
      @test
    end
  end
end
