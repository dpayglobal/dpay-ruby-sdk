# frozen_string_literal: true

module DPay
  class PayoutInstruction
    def self.create(positions, fee_mode = PayoutFeeMode::NET)
      new(positions, fee_mode)
    end

    def initialize(positions, fee_mode = PayoutFeeMode::NET)
      raise InvalidArgumentError, "Payout instruction requires at least one position" if positions.empty?
      unless positions.all?(PayoutPosition)
        raise InvalidArgumentError, "Positions must be DPay::PayoutPosition instances"
      end

      PayoutFeeMode.assert_valid(fee_mode)

      @positions = positions.dup.freeze
      @fee_mode = fee_mode
      freeze
    end

    def to_h
      { "fee_mode" => @fee_mode, "positions" => @positions.map(&:to_h) }
    end
  end
end
