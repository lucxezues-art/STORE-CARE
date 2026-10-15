# StockCare — Food Batch and Expiry Monitoring System

A Dart command-line assignment prototype for the fictional scenario **Sierra Trading Company**. It helps track food batches, expiry alerts, FEFO (First Expired, First Out) recommendations, sales, disposal, waste cost, batch history, and security-event metadata.

## Requirements

- Dart SDK installed
- Windows PowerShell, Windows Terminal, or another terminal

## Run

```powershell
dart --version
dart run stockcare.dart
```

The program creates a local `stockcare_data` directory when it runs and stores inventory in `inventory.json` and security-event metadata in `security-events.jsonl`.

## Date input

Batch dates accept `YYYY-M-D` and `YYYY-MM-DD`, for example `2026-10-2` or `2026-10-02`. Invalid calendar dates are rejected.

## Privacy and data safety

Only the Dart source and this README belong in the public repository. Keep local inventory records, security logs, credentials, and other private operational data out of GitHub. This is an educational prototype and is not connected to a live company system.
