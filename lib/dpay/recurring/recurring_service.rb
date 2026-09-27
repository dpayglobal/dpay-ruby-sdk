# frozen_string_literal: true

module DPay
  # Recurring payments shared by payment methods (today BLIK). Registration and charges go through
  # payments.register with RegisterPaymentRequest#with_recurring_registration and #with_recurring_alias.
  class RecurringService
    CANCEL = "cancel"

    def initialize(api)
      @api = api
    end

    # Current status and terms of the recurring payment registered for this service.
    def status(alias_value)
      body = {
        "service" => @api.service,
        "alias" => alias_value,
        "checksum" => @api.checksum.secret_second(@api.service, [alias_value])
      }

      RecurringStatus.from_api(payload(post("/api/v1_0/payments/recurring/status", body)))
    end

    # Retries a declined recurring charge (transaction_id of the charge) with the same BLIK transaction - up to
    # 3 times within 5 minutes, only after declines the customer can fix, e.g. INSUFFICIENT_FUNDS. Not retryable:
    # InvalidRequestError with the reason in field_errors["retry"] (e.g. DECLINE_NOT_RETRYABLE, RETRY_LIMIT_REACHED).
    def retry(transaction_id)
      body = {
        "service" => @api.service,
        "transaction_id" => transaction_id,
        "checksum" => @api.checksum.secret_second(@api.service, [transaction_id])
      }

      RecurringRetryResult.from_api(payload(post("/api/v1_0/payments/recurring/retry", body)))
    end

    # Cancels the recurring payment (for BLIK: unregisters the alias at BLIK); later charges with the alias are
    # rejected. The checksum ends with the operation name, so a status checksum cannot cancel. Returns the new
    # status (UNREGISTERED).
    def cancel(alias_value, reason = nil)
      body = { "service" => @api.service, "alias" => alias_value }
      body["reason"] = reason unless reason.nil?
      body["checksum"] = @api.checksum.secret_second(@api.service, [alias_value, CANCEL])

      status = payload(post("/api/v1_0/payments/recurring/cancel", body))["status"]
      status.is_a?(String) ? status : RecurringStatus::UNREGISTERED
    end

    private

    def post(path, body)
      @api.post_json(Internal::BaseUrls::API_PAYMENTS, path, body)
    end

    def payload(data)
      data["data"].is_a?(Hash) ? data["data"] : {}
    end
  end
end
