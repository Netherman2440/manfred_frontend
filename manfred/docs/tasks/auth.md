# Auth: Login Screen, Bearer Token, Refresh

## Cel

Wprowadzić ekran logowania jako pierwsze co user widzi w aplikacji, oraz mechanizm trzymania access + refresh JWT i automatycznego dołączania ich do każdego requestu HTTP/SSE/multipart. Aplikacja nie startuje do głównego UI dopóki user nie ma ważnej pary tokenów. Bez ekranu rejestracji, bez "zapomniałem hasła".

Specyfikacja jest self-contained dla frontendu i zawiera pełny kontrakt API, którego oczekuje od backendu.

## Kontekst lokalny

Stan obecny frontendu:
- Wejście aplikacji w [main.dart](../../lib/main.dart) - `AppInitGuard` czeka na `userMeProvider` i pokazuje główny ekran (`ChatWorkspacePage`) gdy zwróci usera. Brak ekranu logowania, brak storage tokenu.
- HTTP wykonywany przez [ManfredApiClient](../../lib/core/api/manfred_api_client.dart). Klient owrapowuje `http.Client` z package `http: ^1.5.0`. Każda metoda (`getJson`, `sendJson`, `sendSse`, `sendMultipart`, `sendMultipartSse`) sama ustawia headers per request. Nie ma centralnego interceptora - rozwiązanie: podklasa `http.BaseClient` która override'uje `send()` i wstrzykuje header `Authorization` dla wszystkich requestów.
- State management: `flutter_riverpod: ^2.6.1`. `userContextProvider` w [user_context_provider.dart](../../lib/features/user/application/user_context_provider.dart) hardkoduje `userId: 'default-user'`. `httpClientProvider` zwraca surowy `http.Client`. `manfredApiClientProvider` używa baseUrl z `userContext`.
- Sessions repo [sessions_repository.dart](../../lib/features/sessions/data/sessions_repository.dart) konstruuje paths `/users/$userId/sessions` i `/users/$userId/sessions/$sessionId`. User repo wywołuje `/users/me`.
- Brak zależności na secure storage. Pubspec nie ma `flutter_secure_storage`.
- Target platformy w `pubspec.yaml`: android, ios, linux, macos.

Powód zmiany teraz: backend wprowadza wymaganie JWT bearer tokenu na każdym endpoincie poza `/auth/login`, `/auth/refresh`, `/health`. Bez auth flow w aplikacji nic poza login screen nie zadziała.

## Scope

In-scope:
- Nowy feature `lib/features/auth/` (domain/data/application).
- Pakiet `flutter_secure_storage` do persystencji access + refresh tokenu.
- `AuthedHttpClient extends http.BaseClient` w `lib/core/api/` - wstrzykuje `Authorization: Bearer <access>` w `send()`, obsługuje refresh-on-401 (jeden retry, z mutexem żeby równoległe requesty nie odpalały N refreshy).
- Login screen (`lib/features/auth/presentation/login_page.dart`): pola username, password, przycisk Sign in, error message przy 401. Brak linków do rejestracji / forgot password.
- Riverpod state: `authStateProvider` z trzema stanami (`checking`, `authenticated`, `unauthenticated`).
- Splash logic w `AppInitGuard`: na start sprawdza czy mamy refresh token w secure storage → jeśli tak, robi cichy `POST /auth/refresh` żeby zweryfikować i odświeżyć parę → na sukces idziemy do `ChatWorkspacePage`, na 401 czyścimy storage i pokazujemy login. Jeśli brak refresh tokenu w storage → login.
- Logout przycisk gdzieś w UI (np. menu w `ChatWorkspacePage` - dokładne miejsce do ustalenia przy implementacji): czyści secure storage, resetuje `authStateProvider`, redirect do login.
- Migracja paths: wszystkie `/users/$userId/...` → `/users/me/...`. `userContextProvider` przestaje przechowywać `userId`.
- Multi-request lock na refresh: kiedy jeden request dostaje 401 i odpala refresh, kolejne równoległe requesty czekają na wynik tego refreshu i po sukcesie używają nowego tokenu zamiast robić własne `/auth/refresh`. Implementacja: `Completer<void>?` w `AuthedHttpClient`.

Out-of-scope:
- Ekran rejestracji.
- "Zapomniałem hasła".
- Zmiana hasła z poziomu UI.
- Biometric login (Face ID/Touch ID gating).
- "Remember me" toggle - access i refresh zawsze idą do secure storage; brak in-memory only mode.
- Wyświetlanie expiry / czasu do wylogowania.
- Toast/snackbar "Sesja wygasła" po wymuszonym logout (akceptowalne: zwykły redirect do login screen).
- Migracja istniejących lokalnych preferencji - nie ma żadnych do migracji.

## Kontrakt z backendem

Endpointy do skonsumowania (host bazowy: `MANFRED_API_BASE_URL`, np. `http://127.0.0.1:3000/api/v1`):

### POST /auth/login

Request (JSON):
```json
{ "username": "string", "password": "string" }
```

Response 200:
```json
{
  "access_token": "<jwt>",
  "refresh_token": "<jwt>",
  "token_type": "bearer",
  "access_expires_in": 900,
  "refresh_expires_in": 2592000
}
```

Response 401: `{ "detail": "Invalid credentials" }`. Backend nie rozróżnia "user nie istnieje" od "złe hasło" - UI też nie powinien rozróżniać. Wyświetlamy generyczne "Nieprawidłowy login lub hasło".

Response 400 dla pustych pól - walidujemy po stronie klienta przed wysłaniem.

### POST /auth/refresh

Request (JSON):
```json
{ "refresh_token": "<jwt>" }
```

Response 200: identyczny shape jak `/auth/login` - zawiera **nową parę** (rotacja). Klient zawsze zastępuje oba tokeny w storage.

Response 401: refresh expired / signature mismatch / user usunięty. Klient czyści storage i pokazuje login.

### Każdy inny endpoint

Header: `Authorization: Bearer <access_token>`.

Response 401 oznacza nieaktualny access token → klient próbuje raz `/auth/refresh` → na sukces ponawia oryginalny request z nowym access tokenem → na ponowne 401 (z refreshu) wymusza logout.

Endpointy zwolnione z dodawania headera (mimo że klient mógłby dodać):
- `POST /auth/login`
- `POST /auth/refresh`
- `GET /health` (frontend i tak go nie wywołuje)

### Zmiana shape /users

Stare paths (do usunięcia z kodu):
- `/users/$userId/sessions`
- `/users/$userId/sessions/$sessionId`

Nowe paths:
- `GET /users/me` - bez zmian semantyki. Response: `{id, name}` gdzie `name` to username.
- `GET /users/me/sessions` - zwraca sesje bieżącego usera. Response shape jak dziś (`{data: [...]}` z entries zawierającymi `user_id`).
- `GET /users/me/sessions/$sessionId` - szczegóły sesji bieżącego usera.

Domain models (`SessionListEntry`, `SessionDetails`) zachowują pole `userId` z response - to OK, backend nadal zwraca `user_id` per sesja.

### SSE i multipart

Backend nadal akceptuje SSE i multipart na endpointach chat. Token sprawdzany **tylko przy nawiązaniu** połączenia (start streama). Stream w toku przeżyje wygaśnięcie access tokenu. Nie próbujemy odświeżać tokenu w trakcie aktywnego streama - jeśli stream się skończy i kolejny request dostanie 401, włącza się standardowy refresh-on-401.

## Plan zmian

### Pubspec
- [pubspec.yaml](../../pubspec.yaml): dodać `flutter_secure_storage: ^9.2.0` (lub bieżąca stable).

### Storage tokenów
- `lib/features/auth/data/token_storage.dart`:
  - Klasa `TokenStorage` wrappująca `FlutterSecureStorage`.
  - Klucze: `auth.access_token`, `auth.refresh_token`.
  - Metody: `readAccess()`, `readRefresh()`, `writeTokens(access, refresh)`, `clear()`.
  - Provider Riverpod: `tokenStorageProvider`.

### Domain + DTO
- `lib/features/auth/domain/auth_tokens.dart`: klasa `AuthTokens { accessToken, refreshToken, accessExpiresIn, refreshExpiresIn }`.
- `lib/features/auth/data/auth_dto.dart`: DTO dla request login/refresh i response.

### Auth repository
- `lib/features/auth/data/auth_repository.dart`:
  - Klasa `AuthRepository` (HTTP, używa **surowego** `http.Client`, nie `AuthedHttpClient` - żeby nie wpaść w cykl).
  - Metody: `Future<AuthTokens> login(username, password)`, `Future<AuthTokens> refresh(refreshToken)`.
  - Provider: `authRepositoryProvider`.

### Authed http client
- `lib/core/api/authed_http_client.dart`:
  - `AuthedHttpClient extends http.BaseClient`.
  - Konstruktor: `({required http.Client inner, required TokenStorage storage, required AuthRepository authRepo, required VoidCallback onAuthFailure})`.
  - `Future<http.StreamedResponse> send(http.BaseRequest request)`:
    1. Jeśli path zaczyna się od `/auth/` → puść bez headera, return.
    2. Wczytaj access z storage. Jeśli jest, dodaj `Authorization: Bearer <access>` do `request.headers`.
    3. Wyślij. Jeśli status != 401 → zwróć response.
    4. Status 401: spróbuj refresh przez `_refreshLock`:
       - `Completer` shared: jeśli inny request już refreshuje, czekaj na jego wynik.
       - W refresh: wczytaj refresh z storage; jeśli brak → wywołaj `onAuthFailure` i rzuć `Exception('Unauthenticated')`.
       - Wywołaj `authRepo.refresh(refreshToken)`. Na sukces: `storage.writeTokens(...)` i complete completer.
       - Na 401 z refresh: `storage.clear()`, `onAuthFailure()`, rzuć.
    5. Po sukcesie refresh: **sklonuj oryginalny request** (BaseRequest jest single-use w package:http - dla MultipartRequest trzeba zrobić rebuild z `request.fields`/`request.files`, dla `http.Request` rebuild z `body`/`bodyBytes`). Wyślij sklonowany z nowym tokenem. Jeśli znów 401 → `onAuthFailure()`, rzuć.
  - **Klonowanie requestów**: helper `_cloneRequest(BaseRequest)` rozpoznaje typy (`http.Request`, `http.MultipartRequest`, `http.StreamedRequest`). `StreamedRequest` nie da się klonować - akceptujemy, że na 401 z `StreamedRequest` od razu lecimy w `onAuthFailure`. (Aktualny kod używa `Request` i `MultipartRequest`.)

### Wiring DI
- [user_context_provider.dart](../../lib/features/user/application/user_context_provider.dart):
  - `UserContext` traci pole `userId`. Zostaje `apiBaseUrl`.
  - `httpClientProvider` zostaje (zwraca surowy `http.Client`).
  - **Nowy** `authedHttpClientProvider` zwraca `AuthedHttpClient` skonstruowany z surowego clienta, storage, repo. `onAuthFailure` ustawia `authStateProvider` na `unauthenticated`.
  - `manfredApiClientProvider` używa `authedHttpClientProvider` zamiast `httpClientProvider`.

### Auth state
- `lib/features/auth/application/auth_state_provider.dart`:
  - Enum `AuthState { checking, authenticated, unauthenticated }`.
  - `StateNotifier<AuthState>` z metodami `markAuthenticated()`, `markUnauthenticated()`. Inicjalny stan `checking`.
- `lib/features/auth/application/auth_controller.dart`:
  - Klasa `AuthController` z metodami:
    - `Future<void> bootstrap()` - na starcie aplikacji. Czyta refresh z storage; jeśli brak → `markUnauthenticated()`. Jeśli jest → wywołaj `authRepo.refresh(...)`. Sukces: zapisz oba, `markAuthenticated()`. 401: `storage.clear()`, `markUnauthenticated()`.
    - `Future<void> login(username, password)` - wywołuje `authRepo.login`, zapisuje tokeny, `markAuthenticated()`. Wyjątek przy 401: rzuca dalej do warstwy UI.
    - `Future<void> logout()` - `storage.clear()`, `markUnauthenticated()`, `ref.invalidate(userMeProvider)` i wszelkie data providery które trzymają state per-user.
  - Provider `authControllerProvider`.

### Splash / routing
- [main.dart](../../lib/main.dart) `AppInitGuard`:
  - `initState`: wywołaj `ref.read(authControllerProvider).bootstrap()`.
  - `build` patrzy na `ref.watch(authStateProvider)`:
    - `checking` → spinner.
    - `unauthenticated` → `LoginPage`.
    - `authenticated` → istniejący flow z `userMeProvider`. Gdy `userMeProvider` zwróci error 401 (np. po wymuszonym logout w tle), niech wraca do login.

### Login screen
- `lib/features/auth/presentation/login_page.dart`:
  - Scaffold z formularzem (Form + TextFormField).
  - Pola: username (validator: niepuste), password (`obscureText: true`, validator: niepuste).
  - Przycisk "Zaloguj" wywołuje `authController.login(...)`.
  - Disabled state na czas requestu, spinner w przycisku.
  - Error widget pod formularzem na ApiError z status 401: "Nieprawidłowy login lub hasło". Inne błędy: generyczne "Coś poszło nie tak, spróbuj ponownie".
  - Brak żadnych dodatkowych linków.

### Repo migration (paths)
- [sessions_repository.dart](../../lib/features/sessions/data/sessions_repository.dart):
  - Interface `SessionsRepository` upraszczamy: `fetchSessions()` (bez `userId`) i `fetchSessionDetails(String sessionId)` (bez `userId`).
  - Wszystkie wołania zewnętrzne, które przekazują userId, czyścimy.
  - Implementacje wołają `/users/me/sessions` i `/users/me/sessions/$sessionId`.
- Sprawdzić wszystkich callerów `fetchSessions(userId)` i `fetchSessionDetails(userId, ...)` w `features/sessions/application/` i `ui/screens/chat_workspace/sessions/`. Usuwamy parametr `userId` z sygnatur i argumentów. Domain models (`SessionListEntry.userId`, `SessionDetails.userId`) zostają - to dane zwrócone przez backend, nie path arg.

### Logout button
- W `ChatWorkspacePage` (lub odpowiednie menu/AppBar - decyzja przy implementacji): IconButton z `Icons.logout`, onPressed: `authController.logout()`.

## Ryzyka

- **`http.BaseRequest` jest single-use**. Po raz pierwszym `send()` strumień body jest zużyty. Implementacja klonowania musi explicit obsłużyć `http.Request` (skopiować `bodyBytes`, headers, encoding) i `http.MultipartRequest` (skopiować `fields`, `files` - czyli zachować referencje do `MultipartFile` które same w sobie też mają state). Test ręczny upload pliku + 401 jest must-have.
- **SSE i 401 w środku streama**: zakładamy że to nie występuje (token sprawdzany tylko przy nawiązaniu). Jeśli backend zacznie kiedyś walidować mid-stream, klient sobie nie poradzi - stream się przerwie z błędem, user widzi "rozłączono".
- **Equity refreshu**: jeśli refresh fail w trakcie aktywnej rozmowy (np. user nie używał appki >30 dni), wracamy do login bez próby zachowania stanu UI. Akceptowalne.
- **flutter_secure_storage na Linux/macOS**: używa `libsecret` (Linux) i Keychain (macOS). Wymaga uprawnień systemowych, w niektórych dystrybucjach Linux może wymagać instalacji `libsecret-1-dev`. Sprawdzić przy pierwszym uruchomieniu na docelowym systemie.
- **Multiple flight requests przy starcie**: kilka providerów na raz uderzy w API → wszystkie dostaną 401 → mutex w `AuthedHttpClient` musi działać, inaczej zrobimy 5 równoległych refreshy.
- **Logout w trakcie aktywnego SSE**: stream nie zostanie automatycznie zamknięty po `markUnauthenticated`. Akceptowalne na MVP - kolejny refresh widoku zamknie subscription.

## Acceptance Criteria

- Otwarcie aplikacji bez żadnego tokenu pokazuje `LoginPage` (po krótkim spinerze).
- Po prawidłowym loginie aplikacja idzie do `ChatWorkspacePage` i `/users/me` zwraca prawidłowe dane.
- Po niepoprawnym loginie `LoginPage` pokazuje "Nieprawidłowy login lub hasło", pola pozostają wypełnione (poza hasłem - reset), przycisk znowu klikalny.
- Po zalogowaniu wszystkie requesty (JSON, SSE, multipart) automatycznie wysyłają `Authorization: Bearer <token>`.
- Wyłączenie i ponowne otwarcie aplikacji - bez kroku login - prowadzi do `ChatWorkspacePage` (cichy refresh z storage zadziałał).
- Wymuszone "expired" testowo (manualnie ustawić w storage zepsuty access): pierwszy request dostaje 401, klient robi refresh, request się udaje. User nie widzi przerwy.
- Wymuszone "expired refresh" (manualnie usunąć refresh): kolejny request → `onAuthFailure` → redirect do login.
- Logout button: czyści storage, wraca do `LoginPage`. Ponowne otwarcie appki = znowu login.
- Pięć równoległych requestów z expired access tokenem powoduje **jeden** wywołany `/auth/refresh` (mutex działa).
- Stary path `/users/{userId}/sessions` nie pojawia się nigdzie w kodzie (grep pusty).

## Test Plan

Testy jednostkowe (flutter_test):
- `TokenStorage` - write/read/clear round-trip (z `flutter_secure_storage` mockiem).
- `AuthRepository` - login happy/sad (mock `http.Client`), refresh happy/sad.
- `AuthedHttpClient`:
  - Path `/auth/login` → brak headera w wysłanym requeście.
  - Path zwykły z tokenem → header dodany.
  - 401 → refresh → retry → 200 (`http.Request` body bytes się zachowuje).
  - 401 → refresh 401 → `onAuthFailure` wywołany, brak retry.
  - 5 równoległych 401 → 1 wywołanie `authRepo.refresh()`.
  - `MultipartRequest` 401 → retry działa, files się klonują.

Test manualny:
- Świeży install → login screen.
- Login → main UI.
- Force-close i ponowne otwarcie → main UI bez kroku login.
- Manualnie podmienić access token w storage na zepsuty → SSE chat się odpala, dostaje 401 → refresh → stream idzie. (Lub: dla SSE jest klonowanie problematyczne; jeśli klient po 401 z `sendSse` po prostu rzuci `onAuthFailure` i wróci do login - to też akceptowalne dla MVP, doprecyzować przy implementacji.)
- Logout button → wraca do login → zalogowanie ponowne → wszystko działa.
- Upload pliku z expired tokenem → multipart się retry'uje.

## Rollout / Backward Compatibility

- Brak BC: aplikacja po update wymaga loginu nawet jeśli wcześniej "działała" jako default-user.
- Backend musi być wdrożony jednocześnie (lub przed) frontendem - inaczej `/auth/login` zwróci 404 i app utknie na login screen.
- Pierwsza wersja - `defaultValue` `MANFRED_API_BASE_URL` zostaje `http://127.0.0.1:3000/api/v1`. Po deployu na VPS klient buduje się z `--dart-define=MANFRED_API_BASE_URL=https://...`.
