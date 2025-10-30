# AI agent instructions for this repo

This is a Flutter + Firebase waiter app (multi-platform) with two main roles (Admin/Waiter). The code favors simple, explicit data flows: a single AppRepository orchestrates auth, Firestore sync, cart, and orders, with Riverpod used only for lightweight services.

## Architecture you should follow
- Entry and routing: `lib/main.dart` uses `MaterialApp` with static `routes` and an `AuthGate` home. Although `go_router` is in deps, it is not used here; keep using `MaterialApp.routes` unless doing a project-wide refactor.
- Central state: `AppRepository` (`lib/data/app_repository.dart`) is the source of truth for:
  - Firebase Auth state listening and user role loading from `users/{uid}`
  - Live sync of tables/categories/menu
  - Cart operations and order lifecycle (open/bill/pay/void/transfer)
  - Exposed via `InheritedApp` (see bottom of same file): use `InheritedApp.of(context)` to access `repo` in UI
- Riverpod: `lib/data/providers.dart` exposes lightweight providers for `AuthService`, `FirestoreService`, and `authStateProvider`. Use them for auth state streams or low-level Firestore ops; prefer `AppRepository` for app flows.
- Firestore paths: Always build paths via `FP` in `lib/core/firestore_paths.dart`.
  - Example: `FP.orders(rid)`, `FP.orderItems(rid, orderId)`. Avoid hard-coded strings.
- Restaurant scoping: Use `kRestaurantId` from `lib/core/constants.dart` or `AppRepository.restaurantId`. Don’t duplicate this string in widgets/services.

## Data model and conventions
- Collections (see README for schema): `restaurants/{rid}/tables|categories|menu_items|orders`, with `users/{uid}` at root. Order items live under `orders/{orderId}/items`.
- Status/state enums:
  - Orders: `open | billed | paid | void` (strings in Firestore). See `OrderModel` in `lib/models/order_model.dart`.
  - Tables: `vacant | occupied | billed | cleaning | reserved` (strings). See `TableModel` in `lib/models/table_model.dart`.
- Timestamps: Use `FieldValue.serverTimestamp()` for writes; parse Firestore `Timestamp` defensively (see `OrderModel.fromMap`).
- Availability: `isAvailable` is derived from `TableState` in code; don’t introduce divergent sources of truth.
- DTO patterns: Models implement `fromMap/toMap` with type-safe parsing and sensible defaults (check `TableModel`, `MenuItemModel`, `CategoryModel`).

## Core workflows (use these APIs)
- Auth: use `AppRepository.login/register/logout` and `refreshUserRole()` to sync roles from Firestore. Low-level helpers are in `lib/services/auth_service.dart`.
- Selecting a table: `repo.selectTable(tableOrId)` assigns selected table and tries to attach any open order.
- Cart → Order: 
  - Add items in UI via `repo.addToCart`, then `repo.sendCartToKitchen()` creates an order, writes item documents, and marks the table occupied.
  - Request bill and close: `repo.requestBill()` → `repo.payAndFreeTable()` (or `voidOpenOrderAndFreeTable()`).
- Active order item adjustments:
  - Prefer `repo.addOrUpdateItem(...)` which runs a transaction and updates order totals with `FieldValue.increment` (no full rescan).
  - Alternative: `updateOrderItem/removeOrderItem` followed by internal `_recalcOrderTotals` (reads all items and recomputes).
- Table transfer: `repo.transferTable(orderId: ..., toTableId: ...)` updates order and both tables atomically.

## UI patterns and helpers
- Access the repository: `final repo = InheritedApp.of(context);`
- Validation: use `V` validators in `lib/core/validators.dart`.
- Theming: `buildTheme()` in `lib/core/app_theme.dart` (Material 3, `colorSchemeSeed`).

## Build, run, test
- Ensure Firebase is configured via `lib/firebase_options.dart` (generated). Root `firebase.json` documents the project IDs.
- Install deps and run:
  - `flutter pub get`
  - `flutter run` (or `-d chrome`, `-d windows`)
- Tests: `flutter test` (sample in `test/widget_test.dart`). Lints from `flutter_lints` (see `analysis_options.yaml`).

## Integration notes and gotchas
- Stick to existing routing (MaterialApp routes). Do not introduce `go_router` per-screen unless refactoring globally.
- Always use `FP` and `serverTimestamp`. Keep order totals consistent via the provided repo methods instead of ad-hoc writes.
- Roles are stored in `users/{uid}.role`. Use `AppRepository.currentUser.isAdmin` to gate admin features.
- When adding new Firestore collections under a restaurant, mirror the pattern in `FP` and update `AppRepository` subscriptions if data should be live-synced.
