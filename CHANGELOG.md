# Changelog

Wszystkie istotne zmiany w tym projekcie są dokumentowane w tym pliku.

Format oparty na [Keep a Changelog](https://keepachangelog.com/pl/1.1.0/),
projekt stosuje [Semantic Versioning](https://semver.org/lang/pl/).

## [Unreleased]

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
