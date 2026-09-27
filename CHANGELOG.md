# Changelog

Wszystkie istotne zmiany w tym projekcie są dokumentowane w tym pliku.

Format oparty na [Keep a Changelog](https://keepachangelog.com/pl/1.1.0/),
projekt stosuje [Semantic Versioning](https://semver.org/lang/pl/).

## [Unreleased]

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
