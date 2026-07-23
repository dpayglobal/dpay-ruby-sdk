# dpay Ruby SDK

Oficjalna biblioteka Ruby do integracji z API płatności [dpay.pl](https://dpay.pl).

## Wymagania

- Ruby 3.1 lub nowszy
- Zero zależności runtime

## Instalacja

```bash
gem install dpay
```

Lub dopisz w `Gemfile`:

```ruby
gem "dpay"
```

## Szybki start

```ruby
require "dpay"

dpay = DPay::Client.new(service: "nazwa_serwisu", secret_hash: "twoj_secret_hash")

payment = dpay.payments.register(
  DPay::RegisterPaymentRequest
    .create(
      DPay::Money.pln(1050),
      DPay::TransactionType::TRANSFERS,
      DPay::ReturnUrls.new(
        "https://twojsklep.pl/sukces",
        "https://twojsklep.pl/blad",
        "https://twojsklep.pl/ipn"
      )
    )
    .with_description("Zamówienie #1234")
    .with_custom("order-1234")
)

redirect_to payment.redirect_url if payment.redirect_url
```

`DPay::Money.pln(1050)` przyjmuje kwotę w groszach (najmniejszej jednostce), czyli 10,50 PLN.
`RegisterPaymentRequest` to budowniczy: każda metoda `with_*` zwraca `self`, więc wywołania można łączyć w łańcuch.

## Obsługa IPN

Brama traktuje jako potwierdzenie dokładnie treść odpowiedzi, nie kod HTTP. Musi to być dokładnie napis
`"OK"` (dostępny jako stała `DPay::IpnEvent::ACK`) - jakikolwiek inna treść w body oznacza dla dpay.pl,
że powiadomienie nie zostało obsłużone i zostanie wysłane ponownie.

```ruby
begin
  event = DPay::IpnVerifier.construct_event(request.raw_post, "twoj_secret_hash")
rescue DPay::SignatureVerificationError
  return render plain: "Invalid signature", status: :bad_request
end

mark_order_as_paid(event.id, event.amount) if event.transfer? || event.capture?

render plain: DPay::IpnEvent::ACK
```

`event.amount` to surowy string dziesiętny, a nie `DPay::Money` - payload IPN nie niesie informacji
o walucie. Zawsze porównaj tę wartość z kwotą własnego zamówienia przed oznaczeniem go jako opłacone,
zamiast ufać wyłącznie faktowi otrzymania powiadomienia.

## Zwroty

```ruby
dpay.refunds.create("identyfikator-transakcji")
dpay.refunds.create("identyfikator-transakcji", DPay::Money.pln(500), "reklamacja")

availability = dpay.refunds.check_availability("identyfikator-transakcji")
availability.available?
```

## Szczegóły transakcji i banki

```ruby
transaction = dpay.payments.details("identyfikator-transakcji")
transaction.paid?
transaction.available_refund_amount.to_decimal
transaction.refunds

banks = dpay.banks.for_service
```

## Karty S2S

```ruby
public_key = dpay.cards.public_key

encrypted = DPay::CardEncryptor.new.encrypt(
  DPay::CardData.new("4111111111111111", "123", "12/28"),
  "identyfikator-transakcji",
  public_key
)

device_info = DPay::DeviceInfo.create(
  browser_accept_header: "text/html", browser_language: "pl-PL", browser_color_depth: 24,
  browser_screen_height: 1080, browser_screen_width: 1920, browser_tz: -60,
  browser_user_agent: "Mozilla/5.0", system_family: "Windows", geo_localization: "52.2297,21.0122",
  device_id: "device-1", application_name: "sklep"
)

result = dpay.cards.pay_otp(
  "identyfikator-transakcji",
  DPay::CardPaymentRequest.create(device_info).with_encrypted_card_data(encrypted)
)

return render_html(result.three_ds_form_html) if result.three_ds_form?
offer = result.dcc_offer if result.dcc_offer?
```

Klucz publiczny jest rotowany - pobieraj go przed każdą próbą płatności, nie przechowuj go u siebie.

## Obsługa błędów

Wszystkie wyjątki SDK dołączają moduł `DPay::Error`, więc `rescue DPay::Error` łapie każdy z nich.

```ruby
begin
  payment = dpay.payments.register(request)
rescue DPay::InvalidRequestError => e
  e.field_errors
rescue DPay::ApiError => e
  e.http_status
  e.error_code
rescue DPay::TransportError
  # błąd sieci - status płatności jest nieznany, sprawdź go przez payments.details()
rescue DPay::Error => e
  # dowolny inny błąd SDK, np. DPay::InvalidArgumentError
end
```

| Wyjątek | Kiedy |
|---|---|
| `DPay::AuthenticationError` | HTTP 401 - niepoprawny checksum |
| `DPay::InvalidRequestError` | HTTP 400 lub 422 - błędne dane wejściowe, patrz `field_errors` |
| `DPay::AccessDeniedError` | HTTP 403 |
| `DPay::NotFoundError` | HTTP 404 |
| `DPay::RateLimitError` | HTTP 429, dodatkowo `retry_after`, `limit`, `remaining` |
| `DPay::ApiServerError` | HTTP 5xx |
| `DPay::PaymentRejectedError` | rejestracja płatności odrzucona mimo HTTP 200 |
| `DPay::CardPaymentError` | płatność kartą odrzucona mimo HTTP 200 |
| `DPay::SignatureVerificationError` | niepoprawny lub brakujący podpis IPN |
| `DPay::TransportError` | błąd sieci lub transportu HTTP |
| `DPay::InvalidArgumentError` | niepoprawny argument przekazany do SDK |

## Konfiguracja

| Opcja | Typ | Opis |
|---|---|---|
| `service` | `String` | Nazwa Punktu Płatności z panelu dpay.pl (wymagane) |
| `secret_hash` | `String` | Klucz Secret Hash z panelu dpay.pl (wymagane) |
| `timeout` | `Integer` | Timeout HTTP w sekundach (domyślnie `30`) |
| `http_client` | obiekt z metodą `#request` | Własny transport, np. proxy, retry albo testy |
| `base_urls` | `Hash` | Nadpisanie hostów API: `api_payments`, `panel`, `gateway` |

## Testowanie integracji

```ruby
require "dpay/testing"

transport = DPay::Testing::MockHttpClient.new
transport.queue_json(200, { "transactionId" => "tx-1", "msg" => "https://secure.dpay.pl/pay/1" })

dpay = DPay::Client.new(service: "test", secret_hash: "test", http_client: transport)

request = DPay::RegisterPaymentRequest.create(
  DPay::Money.pln(1050),
  DPay::TransactionType::TRANSFERS,
  DPay::ReturnUrls.new("https://twojsklep.pl/sukces", "https://twojsklep.pl/blad", "https://twojsklep.pl/ipn")
)

payment = dpay.payments.register(request)

transport.last_request_body["value"] # => "10.50"
```

`DPay::Testing::MockHttpClient` implementuje ten sam interfejs co domyślny transport (`#request`), więc
można go podać jako `http_client:` bez żadnych innych zmian w kodzie testowanym.

## Licencja

Apache-2.0
