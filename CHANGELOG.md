# Changelog

Wszystkie istotne zmiany w tym projekcie są dokumentowane w tym pliku.

Format oparty na [Keep a Changelog](https://keepachangelog.com/pl/1.1.0/),
projekt stosuje [Semantic Versioning](https://semver.org/lang/pl/).

## [Unreleased]

## [0.3.0] - 2026-11-19

Wersja dogania dokumentację API dpay (OpenAPI 1.6.0) i działa z obecnym API - nie wymaga nowego wydania API.

### Breaking

- **BREAKING** `refunds.check_availability` zwraca `DPay::RefundAvailability` (niedostępny) zamiast rzucać wyjątek
  dla każdej odpowiedzi 4xx z kluczem `refund`, w tym 404 (transakcja nie istnieje, wcześniej
  `DPay::NotFoundError`) i 423 (zwrot przez BOK dpay). Przyczynę rozróżnia `http_status`. Rozstrzyga treść
  odpowiedzi, nie lista kodów. Nadal rzucają: 401 "Unauthorized request" (`DPay::AuthenticationError`), każda
  odpowiedź bez klucza `refund` - tak API odpowiada na 422 (walidacja) i 429 (limit zapytań) - oraz każde 5xx.
  Stała `RefundService::AVAILABILITY_STATUSES` nie jest już używana.
- **BREAKING** Waluta kwoty trafia do `currency_code`: `DPay::Money` w walucie innej niż PLN wysyła
  `currency_code` bez `with_currency_code` (wcześniej np. `DPay::Money.of(49_900, "CZK")` rejestrowało 499.00
  w walucie domyślnej serwisu). `with_currency_code` i `with_phone_number` rzucają `DPay::InvalidArgumentError`,
  gdy waluta różni się od waluty kwoty - dla MB WAY użyj `DPay::Money.of(grosze, DPay::Currency::EUR)` zamiast
  `DPay::Money.pln`. Kwota w PLN bez jawnego kodu wysyła body jak dotąd (bez `currency_code`).
- **BREAKING** `DPay::IpnVerifier.construct_event` przyjmuje IPN `alias_update` (wcześniej rzucał
  `DPay::SignatureVerificationError` "Invalid IPN payload"). Przychodzi on na `url_ipn`, gdy rejestracja nie miała
  `alias_ipn_url` - obsługa, która oznacza zamówienie jako opłacone bez sprawdzenia `transfer?`, potraktowałaby
  zmianę aliasu (np. `ALIAS_DECLINED`) jak wpłatę. Dla `alias_update` `amount` jest puste, a `email`, `custom`
  i `attempt` zwracają `nil`/`0` (te pola nie są podpisane).

### Added

- IPN `alias_update` (BLIK OneClick i płatności cykliczne): `DPay::IpnVerifier.construct_event` weryfikuje podpis
  `sha256(id + hash + type + version)`, `IpnType::ALIAS_UPDATE`, `IpnEvent#alias_update?` i `#alias_update`
  (`DPay::AliasUpdate` ze stałymi `change_type`, `alias_type` i `alias_status`).
- `DPay::CardError` (`code`, `decline_code`, `decline_message`): `DPay::CardPaymentError#card_error` z obiektu
  `error` odmowy karty oraz `DPay::ApiError#card_error` i `#transaction_id` z pól `cardError` i `transactionId`
  błędu Payments API (np. odrzucone pobranie na zapisanej karcie).
- `client.payouts.list` i `iterate` (`POST /api/v1/pbl/withdraws`, filtry `date_from`, `date_to`, `state`,
  `type`, strony do 200; nieznany filtr lub wartość złego typu rzuca `DPay::InvalidArgumentError`) oraz `details_full` (`POST /api/v1/pbl/withdraws/details/full`: nagłówek, sumy całego
  rozliczenia i pozycje z `payment_id`, `custom`, `ipksef`, strony do 500); modele `DPay::PayoutPage`,
  `DPay::PayoutListItem`, `DPay::PayoutSettlement`, `DPay::SettlementPosition`, `DPay::PageMeta`,
  `DPay::PayoutState`, `DPay::PayoutType`.
- `DPay::PayoutDetails#currency` (z `currency_code`, PLN gdy go brak), `#export_date` i `#paysafecard?`
  (prawda tylko dla liczby całkowitej JSON `1`, jak `DPay::PayoutListItem#declined?`).
- `refunds.create`: opcjonalny piąty argument `message_id` - nagłówek `DigitalPayments-PSP-Message-ID`
  (tytuł przelewu `dpay.pl zwrot <message_id>`, poza sumą kontrolną).
- `DPay::RegisteredPayment#multibanco` (`DPay::MultibancoReference`: encja, referencja, kwota, ważność)
  i `#paid_transaction` (`DPay::RegisteredTransaction` z odpowiedzi "Transaction paid", statusy pending, paid,
  captured, canceled).
- Typowane obiekty webhooków: `DPay::WebhookEvent#payment`, `#refund`, `#recurring_payment`, `#payout`
  (`DPay::PaymentObject`, `DPay::RefundObject`, `DPay::RecurringPaymentObject`, `DPay::PayoutObject`),
  `DPay::Failure`, `DPay::DeclineCode` (22 kody odmów dpay) i `DPay::FailureCategory`.
- `DPay::RecurringRetryResult#success?` i `DPay::RetryRefusal` (kody `errors.retry` odmowy ponowienia).
- `DPay::Transaction#rate`, `#minimal_fee`, `#permanent_fee` i `#urls` (`DPay::TransactionUrls`).
- `DPay::ApplePayRequest#with_email` i `DPay::CardPaymentResult#apple_pay_merchant_session` (sesja
  ApplePayMerchantSession z `redirectText` odpowiedzi APPLE_PAY_INIT).
- `DPay::RateLimitError#reset` (nagłówek `X-RateLimit-Reset`), `DPay::Currency::USD` i `DPay::Currency::RON`,
  `DPay::DeviceInfo#browser_java_enabled`, `DPay::PayoutPosition.valid_polish_iban?`.
- `spec/fixtures/api_vectors.json`: wektory IPN transfer, dcb i alias_update, sum list i szczegółów wypłat oraz
  `server_trim` (przycinanie łańcuchów przez API panelu: wejście, wysłane body, suma kontrolna);
  golden PHP 0.3.0 w teście zgodności (37 wywołań, w tym lista i pełne szczegóły wypłat, identyfikator zwrotu,
  Apple Pay z emailem, MB WAY, RON i pusty kanał).

### Changed

- Walidacja przed wysłaniem tego, co API i tak odrzuca (422 lub 400):
  - etykieta `register_blik_alias` (`DPay::BlikAliasRegistration`) i `recurring_registration`
    (`DPay::RecurringRegistration`) do 35 znaków (limit BLIK, wcześniej 50);
  - `mb_way_direct` wymaga kanału (`with_channel("373")`) i `DPay::DeviceInfo` z `with_browser_java_enabled`;
  - kanał bezpośredni wymaga emaila, imienia i nazwiska płatnika oraz `with_accept_tos`; kanały `tester`,
    `paypal`, `installment` i `paysafecard` są odrzucane; pusty kanał (`""`) jest wysyłany jak dotąd i nie jest
    kanałem bezpośrednim;
  - `phone_number` 9-15 znaków, `alias_ipn_url` do 500 znaków;
  - `efaktura` nie łączy się z `blik_code`, `blik_alias`, `register_blik_alias`, płatnościami cyklicznymi
    ani aliasami kart;
  - `DPay::PayoutPosition`: IBAN `PL` + 26 cyfr z poprawną sumą kontrolną mod 97 (spacje i małe litery dozwolone)
    i kwota powyżej 0.
- `DPay::ApiError#transaction_id` przeniesione z `DPay::PaymentRejectedError` do klasy bazowej (bez zmiany
  zachowania i konstruktora `PaymentRejectedError`).
- Podpis IPN liczy `id`, `type`, `amount`, `email` i `custom` tylko z wartości skalarnych, a `attempt` i `version`
  tylko z liczb (inaczej `0`) - jak SDK PHP.
- Pusty identyfikator transakcji w `refunds.create`, `refunds.check_availability` i `payments.details` rzuca
  `DPay::InvalidArgumentError` (`transaction_id must not be empty`, a dla wartości innej niż `String`
  `transaction_id must be a string`) zamiast wysyłać żądanie, które API odrzuca kodem 422.
- Wzorce walidacji kotwiczą cały ciąg (`\A...\z`, nigdy kotwice linii `^`/`$`, które w Ruby przepuściłyby np.
  `"x\n123456"`) - SDK Ruby już tak działało (bez zmiany zachowania); testy pilnują teraz wektorów SDK PHP
  z końcowym `"\n"` (nagłówek, identyfikator zwrotu, karta, daty, `DPay::Money`, waluta, BLIK,
  `partner_platform`, częstotliwość, `starting_after`, `webhook-timestamp`, `DPay::Transaction#minimal_fee`).

### Fixed

- Żądania API panelu (`/api/v1/pbl/*`: zwroty, `payments.details`, `banks.for_service`, wypłaty) wysyłają
  i podpisują każdy łańcuch przycięty tak jak API (globalne `TrimStrings` Laravel 13, `Str::trim()`: białe znaki
  ASCII, NUL, spacje Unicode i znaki niewidoczne, np. U+00A0, U+200B, U+FEFF - 65 punktów kodowych,
  `DPay::Internal::ServerTrim`; `String#strip` usuwa tylko białe znaki ASCII i NUL) - wcześniej identyfikator
  transakcji, powód zwrotu, nazwa serwisu lub data filtra z takim znakiem na brzegu kończyły się 401
  "Unauthorized request". Powód, z którego nic nie zostaje, jest wysyłany jako `""` (API liczy go jako pusty
  segment); pusta po przycięciu nazwa serwisu, identyfikator transakcji lub data filtra rzucają
  `DPay::InvalidArgumentError`. Żądania API płatności (`api-payments`) bez zmian.
- `DPay::PayoutDetails#direct_settlement?` i `#declined?` oraz `DPay::PayoutListItem#declined?` są prawdziwe
  tylko dla liczby całkowitej JSON `1` (tak wysyła API) - wcześniej także np. dla `"1abc"`, `"1"` czy `1.0`;
  `#paysafecard?` także dla `true`.

## [0.2.0] - wydanie razem z wdrożeniem API dpay

Wersja wymaga API dpay z tym samym wydaniem (wspólne API płatności cyklicznych, suma kontrolna capture
i anulowania kart). Zmiany łamiące zgodność są oznaczone jako **BREAKING**.

### Added

- `client.recurring` (`DPay::RecurringService`): `status`, `retry` i `cancel` płatności cyklicznej
  (`/api/v1_0/payments/recurring/*`), modele `DPay::RecurringStatus`, `DPay::RecurringRegistrationInfo`,
  `DPay::RecurringRetryResult`.
- `RegisterPaymentRequest#with_recurring_registration(DPay::RecurringRegistration)` - rejestracja płatności
  cyklicznej (modele O, A i M, `terms_url` wymagany) z kodem BLIK klienta.
- `RegisterPaymentRequest#with_recurring_alias` - obciążenie zapisanej płatności cyklicznej bez kodu BLIK;
  alias wchodzi do sumy kontrolnej. `#with_client_context` - opcjonalne IP i przeglądarka klienta przy obciążeniu.
- Webhooki: `DPay::WebhookVerifier.construct_event` i `.verify` (Standard Webhooks, podpis `v1`, tolerancja czasu,
  kilka podpisów i sekretów w czasie rotacji; nagłówki z `Hash` z kluczami `String` lub `Symbol` w dowolnej
  wielkości liter albo w formacie Rack `HTTP_WEBHOOK_ID`), `DPay::WebhookEvent`, `DPay::WebhookEventType`.
- `client.events` (`DPay::EventService`): historia zdarzeń z filtrami, `list` i `iterate` po stronach
  (`DPay::EventPage`).
- `DPay::WebhookTarget` - własny adres zdarzeń w rejestracji płatności (`#with_webhook`), zwrocie
  (`refunds.create`) i capture karty (`cards.capture`); `RegisterPaymentRequest#with_reference`.
- `DPay::ApiError#reason`, `DPay::PaymentRejectedError#error_description` (kod błędu także
  z `additionalInfo.error`), `DPay::RegisteredPayment#recurring_alias` i `#recurring_methods`.
- `spec/fixtures/api_vectors.json` - wspólne wektory sum kontrolnych i podpisów webhooków wszystkich SDK dpay.

### Changed

- **BREAKING** `cards.capture` i `cards.cancel` wysyłają `service` i sumę
  `sha256(operacja|service|transaction_id|amount|hash)` - API odrzuca je bez sumy (401).
- **BREAKING** `DPay::ReturnUrls`: adres IPN jest opcjonalny (`ipn` może być `nil`); bez niego `url_ipn`
  nie jest wysyłany, a IPN nie przychodzi (wynik przychodzi webhookiem).
- Kod błędu API (`DPay::ApiError#error_code`) pochodzi z pola `code` (np. `CHECKSUM_REQUIRED`,
  `WEBHOOK_URL_INVALID`), potem z `errorcode`.
- `ChecksumCalculator#ordered_body` przyjmuje całe body i spłaszcza obiekty zagnieżdżone (np. `webhook`).

### Removed

- **BREAKING** `BlikService#recurring_status`, `DPay::BlikRecurringRegistration`, `DPay::BlikRecurringStatus`,
  `DPay::BlikRecurringRegistrationInfo` i `RegisterPaymentRequest#with_register_blik_recurring_alias` - API
  usunęło te endpointy i pole; użyj `client.recurring` i `#with_recurring_registration`.
- **BREAKING** `BlikAliasType::PAYID` (aliasy OneClick są tylko `UID`), `TransactionType::BLIK_RECURRING`
  i `TransactionType::BIZUM_DIRECT` (API odrzuca je kodem 422).

### Deprecated

- `IpnType::CAPTURE`, `IpnEvent#capture?` i `#capture_payment_id` - dpay nie wysyła już IPN typu `capture`;
  użyj zdarzenia `payment.captured`.

## [0.1.0] - 2026-07-23

### Added

- Klient `DPay::Client` z serwisami `payments`, `refunds`, `banks`, `blik`, `cards`, `payouts`.
- Rejestracja płatności i szczegóły transakcji.
- Zwroty pełne i częściowe oraz sprawdzanie dostępności zwrotu.
- Lista banków globalna i dla punktu płatności.
- Aliasy BLIK: rejestracja, wyrejestrowanie, status cykliczności.
- Płatności kartowe S2S: klucz publiczny, OTP, preautoryzacja, capture, anulowanie, Google Pay, Apple Pay, DCC.
- Szczegóły wypłat.
- Weryfikacja IPN (`DPay::IpnVerifier`) z `DPay::IpnEvent::ACK`.
- Wartości `DPay::Money` i `DPay::Currency` oraz pełna hierarchia błędów z markerem `DPay::Error`.
- `DPay::Testing::MockHttpClient` do testów integracji.
- Sygnatury RBS w `sig/`.

### Notes

- Zero zależności runtime; transport domyślny oparty na `net/http`.
- Parytet wire-protocol z rodziną SDK dpay potwierdzony golden vectors.
