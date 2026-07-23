# frozen_string_literal: true

module DPay
  module HTTP
    class Client
      def request(_api_request)
        raise NotImplementedError, "#{self.class}#request must return a DPay::HTTP::Response"
      end
    end
  end
end
