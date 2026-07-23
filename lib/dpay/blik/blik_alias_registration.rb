# frozen_string_literal: true

module DPay
  class BlikAliasRegistration
    def initialize(label, type = BlikAliasType::UID)
      unless label.is_a?(String) && !label.empty? && label.length <= 50
        raise InvalidArgumentError, "Alias label must be 1-50 characters"
      end

      BlikAliasType.assert_valid(type)

      @label = label
      @type = type
      freeze
    end

    def to_h
      { "label" => @label, "type" => @type }
    end
  end
end
