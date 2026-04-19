# Plan MVP: Integracja frontendu z backendowym kontraktem

## Cel

Przygotować minimalny frontendowy zakres prac potrzebny do działania przeciwko realnemu backendowi w scenariuszu:

- uruchamiam frontend i backend lokalnie,
- frontend ładuje sesje `default-user`,
- mogę wejść w historię sesji,
- mogę kliknąć `New session`,
- mogę wysłać pierwszą wiadomość bez `session_id`,
- frontend dostaje `session_id` z backendu i przełącza się na nową sesję.

Ten dokument opisuje tylko zakres frontendowy MVP. Dokument nadrzędny:
- `/home/netherman/code/manfred/docs/frontend-backend-api-contract-mapping.md`

## Zakres MVP

Frontend musi wdrożyć:
- klient HTTP do backendu,
- prosty kontekst użytkownika z `default-user`,
- listę sesji,
- detail sesji,
- composer wysyłający `POST /chat/completions` z `stream=false`,
- lokalny draft nowej sesji bez zapisanego `session_id`.

Frontend nie musi jeszcze wdrażać:
- SSE i streamingu,
- `deliver`,
- renderowania `reasoning`,
- derived itemów typu `waitingMarker` i `delegatePreview`,
- realnego auth flow.

## Kontrakt produktu dla tego repo

### Źródła danych

W MVP frontend korzysta tylko z:
- `GET /users/{user_id}/sessions`
- `GET /users/{user_id}/sessions/{session_id}`
- `POST /chat/completions` z `stream=false`

Źródło użytkownika:
- hardcoded `default-user`

### Model nowej sesji

`New session` nie tworzy rekordu po stronie backendu.

Zachowanie:
- kliknięcie `New session` czyści aktualny wybór sesji,
- UI przechodzi w stan draftu,
- composer nie ma `session_id`,
- pierwsze `send` wykonuje `POST /chat/completions` bez `session_id`,
- po odpowiedzi frontend zapisuje zwrócone `session_id` jako aktywne.

## Minimalny model stanu

### `userContextProvider`

Zakres:
- `userId = "default-user"`
- `apiBaseUrl`

### `sessionsListProvider`

Zakres:
- pobranie listy sesji,
- refresh po wysłaniu wiadomości,
- stan loading/error/data.

### `selectedSessionIdProvider`

Zakres:
- `String? activeSessionId`
- `null` oznacza nowy draft albo brak wybranej sesji.

### `sessionDetailsProvider`

Zakres:
- pobranie transcriptu dla aktywnej sesji,
- brak pobrania, gdy `selectedSessionId == null`,
- refresh po udanym `send`.

### `composerControllerProvider`

Zakres:
- draft tekstu,
- `isSending`,
- ostatni błąd,
- akcja `send()`.

W MVP ten kontroler nie zarządza streamingiem.

## Model danych po stronie frontendu

### Raw modele domenowe

Frontend powinien umieć przyjąć z backendu co najmniej:
- `SessionItemMessage`
- `SessionItemToolCall`
- `SessionItemToolResult`

`SessionItemReasoning` może istnieć jako model techniczny, ale nie jest wymagany do pierwszego etapu renderingu.

### Presentation models

Na potrzeby MVP UI powinno wystarczyć:

```text
ConversationEntryViewModel
  - message
  - toolCall
  - toolResult
```

Mapowanie:
- `message(role=user)` -> user item,
- `message(role=assistant)` -> agent item,
- `function_call` -> tool card,
- `function_call_output` -> wynik toola pod tą samą kartą albo osobny wpis techniczny.

### Ważna zasada

Widgety nie powinny konsumować:
- backendowych DTO,
- `ChatResponse.output`.

Widgety powinny konsumować wyłącznie:
- modele domenowe,
- albo presentation models.

## Zakres zmian w kodzie

### Zależności

Minimalna rekomendacja:
- `flutter_riverpod`
- prosty klient HTTP, np. `package:http`

W tym etapie nie ma potrzeby dodawania generatorów kodu ani złożonej warstwy serializacji.

### Nowe obszary w `lib/`

```text
lib/
  core/
    api/
      manfred_api_client.dart
      api_error.dart
  features/
    user/
      application/
        user_context_provider.dart
    sessions/
      data/
        sessions_repository.dart
        sessions_dto.dart
      domain/
        session_list_entry.dart
        session_details.dart
        session_item.dart
      application/
        sessions_list_provider.dart
        selected_session_provider.dart
        session_details_provider.dart
    chat/
      data/
        chat_repository.dart
        chat_dto.dart
      application/
        composer_controller.dart
      domain/
        composer_state.dart
        chat_mutation_result.dart
```

### Zmiany w istniejącym UI

- `main.dart`
  - opakowanie aplikacji w `ProviderScope`
- `chat_workspace_page.dart` i podległe widgety
  - przejście z mocków na providery
- `conversation_list.dart`
  - render z `ConversationEntryViewModel`
- `sessions_column.dart`
  - render z `sessionsListProvider`
- `composer_mock.dart`
  - zamiana na prawdziwy composer podpięty do `composerController`

### Co może zostać z mocków

Na etapie MVP mogą jeszcze zostać mockowe:
- prawa kolumna,
- agent rail,
- część dekoracyjnych danych niezwiązanych z transcriptami.

Kluczowe jest, żeby lista sesji i conversation column były już oparte o prawdziwe API.

## Flow użytkownika

### Start aplikacji

1. frontend inicjalizuje `userContextProvider`,
2. frontend ładuje `sessionsListProvider(default-user)`,
3. jeśli lista nie jest pusta, może automatycznie wybrać pierwszą sesję,
4. po wyborze sesji frontend ładuje `sessionDetailsProvider`.

### Wejście w istniejącą sesję

1. użytkownik klika element listy sesji,
2. frontend ustawia `selectedSessionId`,
3. frontend pobiera detail sesji,
4. conversation panel renderuje transcript.

### Nowa sesja

1. użytkownik klika `New session`,
2. frontend ustawia `selectedSessionId = null`,
3. conversation panel pokazuje pusty draft,
4. użytkownik wpisuje pierwszą wiadomość,
5. frontend wywołuje `POST /chat/completions` bez `session_id`,
6. frontend pobiera z odpowiedzi `session_id`,
7. frontend ustawia nową sesję jako aktywną,
8. frontend odświeża listę sesji i detail nowej sesji.

## Acceptance Criteria

- frontend potrafi pobrać listę sesji `default-user`,
- frontend potrafi wejść w detail sesji,
- frontend renderuje co najmniej `message`, `function_call` i `function_call_output`,
- kliknięcie `New session` otwiera pusty draft bez zapisanego `session_id`,
- pierwsza wiadomość tworzy sesję przez `POST /chat/completions`,
- frontend po odpowiedzi przełącza się na nową sesję i pokazuje jej transcript,
- aplikacja poprawnie pokazuje loading i error dla listy, detalu i wysyłki wiadomości.

## Test Plan

- test providera listy sesji z mockowanym API,
- test providera detalu sesji z mockowanym API,
- test `composerController.send()` dla istniejącej sesji,
- test `composerController.send()` bez `session_id` tworzący nową sesję,
- widget test conversation column z danymi:
  - `message`
  - `function_call`
  - `function_call_output`
- widget test `New session -> first send -> switch to created session`.

## Handoff: frontend

Done:
- Zawężono frontendowy zakres do MVP bez streamingu i bez `deliver`.

Contract:
- `default-user` jest tymczasowo trzymany lokalnie w providerze.
- `session details` są kanonicznym transcriptowym źródłem prawdy.
- `chat/completions` służy do wysyłki i utworzenia nowej sesji przy pierwszej wiadomości.

Next role:
- `integrator`

Risks:
- Bez wspólnego mappera DTO -> view model widgety szybko zaczną mieszać logikę prezentacji z transportem.
- Jeśli UI będzie czytać `ChatResponse.output` jako transcript, stan rozmowy zacznie się rozjeżdżać po pierwszym refreshu.
