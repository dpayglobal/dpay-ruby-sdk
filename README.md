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
Adres IPN w `ReturnUrls` jest opcjonalny - bez niego IPN nie przychodzi, a wynik płatności dostaniesz webhookiem.

## Waluta

Waluta płatności to waluta kwoty `DPay::Money`. Kwota w innej walucie niż PLN wysyła `currency_code` sama
(od 0.3.0), np. CZK dla banków czeskich, EUR dla MB WAY, Multibanco i banków słowackich. Serwis musi mieć
tę walutę włączoną (PLN, EUR, CZK, USD, RON).

```ruby
DPay::RegisterPaymentRequest.create(
  DPay::Money.of(49_900, DPay::Currency::CZK), DPay::TransactionType::TRANSFERS, urls
)
```

`with_currency_code` i `with_phone_number` przyjmują tylko walutę kwoty - `DPay::Money.pln` z kodem `EUR` rzuca
`DPay::InvalidArgumentError`.

## MB WAY i kanały bezpośrednie

Kanał bezpośredni (`with_channel`) wymaga emaila, imienia i nazwiska płatnika oraz `with_accept_tos`.
MB WAY wymaga dodatkowo kanału `373` i pełnego `DPay::DeviceInfo` z `with_browser_java_enabled` - SDK sprawdza to
przed wysłaniem (API odpowiedziałoby 422). Pusty kanał (`with_channel("")`) oznacza brak kanału.

```ruby
payment = dpay.payments.register(
  DPay::RegisterPaymentRequest
    .create(DPay::Money.of(1250, DPay::Currency::EUR), DPay::TransactionType::MB_WAY_DIRECT, urls)
    .with_phone_number("+351912345678", DPay::Currency::EUR)
    .with_channel("373")
    .with_payer(DPay::Payer.create.with_email("cliente@example.pt").with_name("Joao", "Silva"))
    .with_accept_tos(true)
    .with_device_info(
      DPay::DeviceInfo.create(
        browser_accept_header: accept, browser_language: "pt-PT", browser_color_depth: 24,
        browser_screen_height: 1080, browser_screen_width: 1920, browser_tz: 0, browser_user_agent: user_agent,
        system_family: "Win32", geo_localization: "38.72,-9.14", device_id: device_id, application_name: "Netscape"
      ).with_browser_java_enabled(false)
    )
)
```

Multibanco (kanał `390`, EUR) zwraca referencję do pokazania płatnikowi:

```ruby
reference = payment.multibanco # DPay::MultibancoReference: entity, reference, amount, expires_at
```

Odpowiedź "Transaction paid" (płatność już opłacona) niesie transakcję w `payment.paid_transaction`
(`DPay::RegisteredTransaction`: `status`, `paid?`, `value`, `payment_date`).

## Płatności cykliczne

Rejestracja idzie razem z płatnością kodem BLIK klienta (kwota `0` - sama zgoda, więcej - opłata inicjalna).
Kolejne obciążenia wysyła Twój serwer, bez kodu.

```ruby
urls = DPay::ReturnUrls.new("https://twojsklep.pl/sukces", "https://twojsklep.pl/blad")

registration = dpay.payments.register(
  DPay::RegisterPaymentRequest
    .create(DPay::Money.pln(0), DPay::TransactionType::TRANSFERS, urls)
    .with_blik_code(kod_blik, request.user_agent, request.remote_ip)
    .with_recurring_registration(
      DPay::RecurringRegistration
        .create("Abonament Premium", DPay::RecurringRegistration::MODEL_O, "https://twojsklep.pl/regulamin")
        .with_alias("SUB-1234")
    )
)
registration.recurring_alias # => "SUB-1234"

charge = dpay.payments.register(
  DPay::RegisterPaymentRequest
    .create(DPay::Money.pln(4999), DPay::TransactionType::TRANSFERS, urls)
    .with_recurring_alias("SUB-1234")
    .with_description("Abonament Premium 10/2026")
)

status = dpay.recurring.status("SUB-1234")  # status.status: ACTIVE, INACTIVE, UNREGISTERED, EXPIRED, DECLINED
dpay.recurring.retry(charge.transaction_id) # po odmowie, np. INSUFFICIENT_FUNDS
dpay.recurring.cancel("SUB-1234", "Rezygnacja klienta")
```

Model `A` (stała kwota) wymaga `with_frequency`, `with_limit_amt`, `with_tot_limit_amt` (kwoty w groszach),
`with_expiration_date` i `with_init_date`, model `M` przyjmuje je opcjonalnie, a model `O` ich nie dopuszcza.
Obciążenie wiąże alias z sumą kontrolną, a anulowanie ma własną sumę - SDK liczy obie.
Limity API: `status` do 60, `retry` i `cancel` do 30 zapytań na minutę (licznik wspólny z resztą API
płatności z tego adresu IP) - nie odpytuj statusu w pętli, wynik przychodzi webhookiem.
Odmowę ponowienia opisuje `e.field_errors["retry"]` (stałe `DPay::RetryRefusal`).
Zmiany statusu płatności cyklicznej przychodzą też jako IPN `alias_update` (patrz Obsługa IPN).

## Webhooki

Zdarzenia (`payment.succeeded`, `refund.failed`, `recurring_payment.canceled` i inne) są podpisane
(Standard Webhooks). Weryfikuj je na surowym body, przed parsowaniem JSON:

```ruby
begin
  event = DPay::WebhookVerifier.construct_event(
    request.raw_post,
    request.headers,
    ENV.fetch("DPAY_WEBHOOK_SECRET") # sekret endpointu z panelu (whsec_...); w czasie rotacji tablica sekretów
  )
rescue DPay::SignatureVerificationError
  return head :bad_request
end

payment = event.payment # DPay::PaymentObject, nil dla innych obiektów
if payment&.status == DPay::PaymentObject::STATUS_SUCCEEDED
  mark_order_as_paid(payment.merchant_reference, payment.amount) # DPay::Money, grosze + waluta
end
failure = payment&.failure
if failure&.retryable?
  # np. DPay::DeclineCode::INSUFFICIENT_FUNDS - klient może zapłacić ponownie
end

head :ok
```

Obiekty: `event.payment`, `event.refund`, `event.recurring_payment`, `event.payout`; surowy `Hash` - `event.object`.

Nagłówki podajesz jako `Hash` (albo obiekt z `#each` zwracającym nazwę i wartość) z kluczami `String` lub `Symbol`
w dowolnej wielkości liter (`"webhook-id"`, `"Webhook-Id"`, `:webhook_id`) albo w formacie Rack (`"HTTP_WEBHOOK_ID"`),
więc zadziała zarówno `request.headers` w Rails, jak i `request.env` w Rack i Sinatrze. Wartość nagłówka może być
tablicą - liczy się pierwszy element. Znacznik czasu może odbiegać od zegara serwera najwyżej o 300 sekund
(`DPay::WebhookVerifier::DEFAULT_TOLERANCE`, inną wartość podasz czwartym argumentem). Sama weryfikacja bez
parsowania: `DPay::WebhookVerifier.verify` z tymi samymi argumentami.

Deduplikuj zdarzenia po `event.id`. Historię zdarzeń (np. po awarii endpointu) pobierzesz przez
`dpay.events.iterate(types: ["payment.succeeded"]) { |event| ... }` albo stronami przez `dpay.events.list`.

Własny adres zdarzeń jednej płatności: `.with_webhook(DPay::WebhookTarget.create("https://twojsklep.pl/webhooks"))`
(podpisywany sekretem webhooków serwisu), a Twój identyfikator zamówienia w zdarzeniach: `.with_reference("order-1234")`.

## Obsługa IPN

IPN przychodzi tylko wtedy, gdy podasz adres IPN w `ReturnUrls` (IPN `alias_update` także na `with_alias_ipn_url`).

Brama traktuje jako potwierdzenie dokładnie treść odpowiedzi, nie kod HTTP. Musi to być dokładnie napis
`"OK"` (dostępny jako stała `DPay::IpnEvent::ACK`) - jakikolwiek inna treść w body oznacza dla dpay.pl,
że powiadomienie nie zostało obsłużone i zostanie wysłane ponownie.

```ruby
begin
  event = DPay::IpnVerifier.construct_event(request.raw_post, "twoj_secret_hash")
rescue DPay::SignatureVerificationError
  return render plain: "Invalid signature", status: :bad_request
end

if event.transfer?
  mark_order_as_paid(event.id, event.amount)
elsif event.alias_update?
  change = event.alias_update # DPay::AliasUpdate: change_type, alias_type, alias_status, ...
end

render plain: DPay::IpnEvent::ACK
```

`event.amount` to surowy string dziesiętny, a nie `DPay::Money` - payload IPN nie niesie informacji
o walucie. Zawsze porównaj tę wartość z kwotą własnego zamówienia przed oznaczeniem go jako opłacone,
zamiast ufać wyłącznie faktowi otrzymania powiadomienia.

IPN `alias_update` (zmiana aliasu BLIK OneClick lub płatności cyklicznej) przychodzi na `with_alias_ipn_url`,
a bez niego na adres IPN. Ma inny podpis (`sha256(id + hash + type + version)`) - `construct_event` rozpoznaje
go po `type`, więc zawsze sprawdzaj typ (`event.transfer?`) przed oznaczeniem zamówienia jako opłaconego: `event.id`
to wtedy płatność, która zarejestrowała alias, a `event.amount` jest puste. Podpis nie obejmuje pól aliasu
(`event.alias_update`) - przed reakcją na zmianę potwierdź stan przez `dpay.recurring.status` lub `dpay.blik.alias`.

## Zwroty

```ruby
dpay.refunds.create("identyfikator-transakcji")
dpay.refunds.create("identyfikator-transakcji", DPay::Money.pln(500), "reklamacja")

# Odpowiedź oznacza przyjęcie zwrotu - wynik przychodzi zdarzeniem refund.succeeded / refund.failed
dpay.refunds.create(
  "identyfikator-transakcji",
  DPay::Money.pln(500),
  nil,
  DPay::WebhookTarget.create("https://twojsklep.pl/webhooks/zwroty", %w[refund.succeeded refund.failed])
)

# Własny identyfikator zwrotu (nagłówek DigitalPayments-PSP-Message-ID) - tytuł przelewu "dpay.pl zwrot RET-1234"
dpay.refunds.create("identyfikator-transakcji", DPay::Money.pln(500), nil, nil, "RET-1234")

availability = dpay.refunds.check_availability("identyfikator-transakcji")
availability.available?
```

`check_availability` rozstrzyga po treści odpowiedzi, nie po liście kodów: HTTP 200 i każda odpowiedź 4xx
z kluczem `refund` to wynik (nie wyjątek) - dziś odmowy biznesowe 400, 402, 404 (transakcja nie istnieje), 406,
409, 410, 411, 423 i biznesowe 401; przyczynę rozróżnia `availability.http_status`. Wyjątek rzucają: błędna suma
kontrolna (401 "Unauthorized request"), każda odpowiedź bez klucza `refund` - tak API odpowiada na błędy walidacji
(422) i limit zapytań (429) - oraz każde 5xx, także z kluczem `refund`.

Identyfikator transakcji, powód i adres webhooka są wysyłane i podpisywane bez białych i niewidocznych znaków
na brzegach - API panelu przycina je przed sprawdzeniem sumy kontrolnej (patrz [Białe znaki](#białe-znaki-w-api-panelu)).

## Szczegóły transakcji i banki

```ruby
transaction = dpay.payments.details("identyfikator-transakcji")
transaction.paid?
transaction.available_refund_amount.to_decimal
transaction.refunds

transaction.rate # prowizja, np. "1.49"
transaction.urls # DPay::TransactionUrls: success, fail, ipn

banks = dpay.banks.for_service
```

## Wypłaty

```ruby
dpay.payouts.iterate({ date_from: "2026-08-01", state: DPay::PayoutState::PROCESSED }) do |payout|
  settlement = dpay.payouts.details_full(payout.id)
  settlement.positions.each do |position|
    position.payment_id # transakcja z IPN, position.custom, position.net, position.fee, position.gross
  end
end
```

`list` zwraca jedną stronę (`per_page` do 200), `details_full` - sumy całego rozliczenia
(`summary_net`, `summary_count`) i stronę pozycji (`per_page` do 500). Filtry `date_from` i `date_to`
to łańcuchy (`String`), `state` - liczba całkowita (`Integer`), `type` - łańcuch; wartość innego typu, nieznany
filtr i pusta data rzucają `DPay::InvalidArgumentError`, a `nil` oznacza brak filtra. `details` i `details_full`
podają walutę wypłaty (`currency`, PLN gdy API jej nie wysyła).

### Białe znaki w API panelu

API panelu (`refunds`, `payments.details`, `banks.for_service`, `payouts`) przycina każdy łańcuch żądania
przed sprawdzeniem sumy kontrolnej - spacje, tabulatory i znaki nowej linii, ale też spacje Unicode (np. U+00A0,
U+3000) i znaki niewidoczne (np. U+200B, U+FEFF). To więcej niż `String#strip`. SDK wysyła i podpisuje te
wartości (także nazwę serwisu) już przycięte, więc `" 2026-08-01\n"` trafia do API jako `"2026-08-01"`.
Identyfikator transakcji, nazwa serwisu i daty, z których nic nie zostaje, rzucają `DPay::InvalidArgumentError`
(`transaction_id must not be empty`); powód zwrotu, z którego nic nie zostaje, jest wysyłany jako pusty.

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

Po preautoryzacji (`pre_auth`) pobierasz środki przez `capture` albo zwalniasz je przez `cancel`. Oba wywołania
SDK podpisuje sumą kontrolną operacji; `capture` przyjmuje też własny adres zdarzenia `payment.captured`:

```ruby
dpay.cards.capture(
  "identyfikator-transakcji",
  DPay::Money.pln(2999),
  DPay::WebhookTarget.create("https://twojsklep.pl/webhooks", ["payment.captured"])
)
dpay.cards.cancel("identyfikator-transakcji") # bez kwoty: cała nieprzechwycona reszta
```

## Obsługa błędów

Wszystkie wyjątki SDK dołączają moduł `DPay::Error`, więc `rescue DPay::Error` łapie każdy z nich.

```ruby
begin
  payment = dpay.payments.register(request)
rescue DPay::InvalidRequestError => e
  e.field_errors
  e.transaction_id # transakcja utworzona przed błędem, np. odrzucone pobranie z karty
  e.card_error     # DPay::CardError: code, decline_code (ISO 8583), decline_message
rescue DPay::RateLimitError => e
  e.retry_after    # sekundy; e.reset - czas Unix odnowienia limitu
rescue DPay::ApiError => e
  e.http_status
  e.error_code # np. CHECKSUM_REQUIRED, WEBHOOK_URL_INVALID
  e.reason     # szczegół kodu, np. "https_required" przy WEBHOOK_URL_INVALID
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
| `DPay::RateLimitError` | HTTP 429, dodatkowo `retry_after`, `limit`, `remaining`, `reset` |
| `DPay::ApiServerError` | HTTP 5xx |
| `DPay::PaymentRejectedError` | rejestracja płatności odrzucona mimo HTTP 200, dodatkowo `transaction_id`, `error_description` |
| `DPay::CardPaymentError` | płatność kartą odrzucona mimo HTTP 200, dodatkowo `card_error` |
| `DPay::SignatureVerificationError` | niepoprawny lub brakujący podpis IPN albo webhooka |
| `DPay::TransportError` | błąd sieci lub transportu HTTP |
| `DPay::InvalidArgumentError` | niepoprawny argument przekazany do SDK |

Odmowa karty z HTTP 200 (`success: false`) rzuca `DPay::CardPaymentError`: `error_code` to komunikat API
(np. `DCC_OFFER_EXPIRED`), a `card_error` - kod odmowy, gdy wystawca go podał. `transaction_id` i `card_error`
ma każdy `DPay::ApiError` (z pól `transactionId` i `cardError` błędu API płatności).

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
