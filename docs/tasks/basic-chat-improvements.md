# Basic chat improvements

## Cel

Repo-local celem frontendu jest zamiana prostego tekstowego composera na podstawowy workspace chat:
- z attachmentami,
- z edycją wcześniejszej wiadomości usera,
- z możliwością wysłania kolejnej wiadomości podczas aktywnego streamu bez twardej blokady inputu.

Ta specyfikacja jest self-contained i zawiera backendowy kontrakt potrzebny frontendowi.

## Kontekst lokalny

Stan obecny frontendu:
- `ComposerController` ma lokalny stan dla streamu i `Stop`, ale `send()` wraca od razu, gdy `state.isBusy` jest `true`,
- `HttpChatRepository` potrafi wysłać JSON i SSE, ale nie ma flow multipart uploadu,
- `SessionMessageItem` ma tylko `role` i `content`,
- `UserMessageItem` renderuje sam tekst bez attachmentów i bez akcji edit,
- overlay providers umieją pokazać pending user message i streaming assistant response, ale nie umieją pokazać queued pending messages ani trybu edycji.

Powód tej zmiany teraz:
- backendowy streaming/cancel już istnieje,
- workspace sessions już mają sens jako kanoniczny transcript,
- teraz UI może wreszcie odsłonić podstawowe interakcje, których użytkownik oczekuje od chatowego workspace.

## Scope

In-scope:
- picker attachmentów i lokalny stan plików w composerze,
- multipart send dla nowej wiadomości z attachmentami,
- render attachment metadata przy user message,
- wejście w tryb edycji wcześniejszej wiadomości usera,
- zapis edycji przez dedykowany backend endpoint i restart streamu,
- queue flow podczas aktywnego streamu zamiast obecnego `return` z `state.isBusy`,
- lokalny pending UX dla queued wiadomości,
- rozszerzenie DTO/domain/widget tests o attachmenty i znaczniki edycji.

Out-of-scope:
- drag and drop polish, progress bary uploadu i zaawansowany upload manager,
- preview binarnych plików w samym kliencie,
- edycja wiadomości assistanta,
- wielowątkowe branchowanie transcriptu,
- queue dla `deliver`,
- background retry po restarcie aplikacji.

## Backend contract needed by frontend

`POST /api/v1/chat/completions`
- wspiera:
  - legacy JSON dla zwykłych wiadomości,
  - multipart dla wiadomości z attachmentami,
- fields dla multipart:
  - `message`
  - opcjonalne `session_id`
  - opcjonalne `stream`
  - pliki `attachments[]`
- `stream=true` nadal zwraca SSE jak dziś:
  - `session`
  - `text_delta`
  - `text_done`
  - `function_call_delta`
  - `function_call_done`
  - `done`
  - `error`

`PATCH /api/v1/chat/sessions/{session_id}/items/{item_id}`
- służy do edycji wcześniejszej wiadomości usera,
- przyjmuje:
  - nowy `message`
  - `retain_attachment_ids[]` dla attachmentów pozostających przy wiadomości
  - opcjonalne nowe `attachments[]`
  - opcjonalne `stream=true`
- po sukcesie backend rewinda transcript i uruchamia nowy run od tego punktu.

`POST /api/v1/chat/sessions/{session_id}/queue`
- służy do przyjęcia nowej wiadomości podczas aktywnego streamu,
- przyjmuje:
  - `message`
  - opcjonalne `attachments[]`
- zwraca acknowledgement z `queued_input_id` i pozycją w kolejce,
- nie otwiera nowego streamu; frontend nadal polega na aktywnym już streamie i późniejszym refetchu.
- jeśli sesja jest już w `waiting`, backend może przyjąć queue, ale nie przetwarza jej, dopóki agent nie wyjdzie z `waiting`.

Session details transcript:
- `message` item może mieć:
  - `attachments`
  - `is_edited`
  - `edited_at`
- attachment ma minimum:
  - `id`
  - `file_name`
  - `media_type`
  - `size_bytes`
  - `path`

## Moduły do zmiany

API client:
- `manfred/lib/core/api/manfred_api_client.dart`
- `manfred/lib/core/api/sse_client.dart`

Chat data/domain:
- `manfred/lib/features/chat/data/chat_repository.dart`
- `manfred/lib/features/chat/data/chat_dto.dart`
- `manfred/lib/features/chat/domain/composer_state.dart`
- ewentualnie nowe modele:
  - `pending_attachment.dart`
  - `queued_message.dart`
  - `edit_target.dart`

Sessions data/domain:
- `manfred/lib/features/sessions/data/sessions_dto.dart`
- `manfred/lib/features/sessions/domain/session_item.dart`
- `manfred/lib/features/sessions/domain/session_details.dart`

Application layer:
- `manfred/lib/features/chat/application/composer_controller.dart`
- `manfred/lib/features/sessions/application/session_overlay_providers.dart`
- `manfred/lib/features/sessions/application/session_details_provider.dart`
- `manfred/lib/features/sessions/application/sessions_list_provider.dart`

UI:
- `manfred/lib/ui/screens/chat_workspace/controls/composer_mock.dart`
- `manfred/lib/ui/screens/chat_workspace/conversation/items/user_message_item.dart`
- ewentualne nowe widgety attachment chip/list/edit banner

Testy:
- `manfred/test/chat_repository_test.dart`
- `manfred/test/chat_transcript_widgets_test.dart`
- nowe testy controllera composera

## Oczekiwane zachowanie

### Attachments

1. Użytkownik wybiera jeden lub więcej plików w composerze.
2. Composer pokazuje je jako lokalny pending stan z możliwością usunięcia przed send.
3. Kliknięcie send:
   - dla zwykłej wiadomości bez attachmentów może dalej użyć lekkiego flow JSON,
   - dla wiadomości z plikami używa multipart,
   - przy `stream=true` działa nadal dotychczasowy overlay streamu.
4. Po refetchu transcript pokazuje attachmenty już jako dane kanoniczne z backendu.

### Edit / rewind

1. Użytkownik wybiera `Edit` na wcześniejszej wiadomości usera.
2. Composer przechodzi w tryb edycji:
   - draft zostaje uzupełniony treścią starej wiadomości,
   - attachmenty tej wiadomości są załadowane do stanu edycji,
   - UI jasno pokazuje, że zapis cofnie późniejszą historię.
3. Zapis edycji:
   - wywołuje backendowy endpoint edit,
   - czyści lokalne overlay dla nowszych itemów,
   - startuje stream regeneracji od zedytowanego punktu.
4. Edit jest dostępny także wtedy, gdy root agent jest w `waiting`.
5. Edit nie jest dostępny dla wiadomości w sub-wątkach/delegowanych threadach.

### Queue

1. Podczas aktywnego streamu user wpisuje kolejną wiadomość.
2. `send()` nie kończy się już no-opem na `isBusy`.
3. Jeśli tryb to aktywny root stream, frontend:
   - wywołuje endpoint `/queue`,
   - czyści draft,
   - pokazuje lokalny pending queued message,
   - pozostawia istniejący stream aktywny.
4. Po refetchu pending local state znika na rzecz stanu kanonicznego.
5. Jeśli sesja jest w `waiting`, queued wiadomość może pozostać oznaczona jako pending do czasu rozwiązania `waiting`.

## Decyzje architektoniczne

- Finalny transcript nadal pochodzi z backendowego refetchu; overlay i pending queue to tylko warstwa UX.
- Attachment picker ma być prosty i stanowy; nie projektujemy jeszcze osobnego upload managera.
- Edit mode i queue mode są wzajemnie wykluczające się.
- Edit w `waiting` jest dozwolony dla root transcriptu.
- Edit w aktywnym `running` powinien nadal wymagać najpierw stabilnego stanu albo `Stop`.

## Edge cases

- użytkownik wybiera attachmenty, ale zamyka edit/send:
  - lokalny stan ma się wyczyścić bez wpływu na backend,
- stream kończy się zanim queue request wróci:
  - frontend i tak robi refetch i pojednanie stanu,
- queued wiadomość nie została jeszcze skonsumowana, a user próbuje wejść w edit:
  - UI powinno zablokować edycję albo wymagać odświeżenia stanu po stronie backendu,
- sesja jest w `waiting`, a user dodaje queued wiadomość:
  - UI może ją pokazać jako pending, ale nie powinno sugerować, że została już przetworzona,
- refetch transcriptu po edit przychodzi z krótkim opóźnieniem:
  - overlay nie może utrzymywać już nowszych, zrewindowanych itemów,
- attachmenty istnieją w transcriptcie, ale lokalny klient nie umie ich previewować:
  - renderujemy metadata/chipy/link-like presentation, nie obiecujemy otwierania plików w tej iteracji.

## Acceptance Criteria

- użytkownik może dodać attachmenty do wiadomości i usunąć je przed wysłaniem,
- transcript user message pokazuje attachment metadata po refetchu,
- użytkownik może wejść w tryb edycji wcześniejszej wiadomości usera,
- zapis edycji czyści nowszy lokalny transcript i uruchamia nowy stream,
- podczas aktywnego streamu wysłanie kolejnej wiadomości odkłada ją do queue zamiast być ignorowane,
- UI pokazuje stan pending dla queued wiadomości i po pojednaniu wraca do stanu kanonicznego,
- obecny flow `Stop` i `deliver` nie ulega regresji.

## Test plan

- testy jednostkowe:
  - mapowanie transcript DTO z attachmentami i polami edycji,
  - przejścia `idle -> editing -> streaming`,
  - przejścia `streaming -> queue_pending -> streaming/refetch`.
- testy widgetowe:
  - render attachment chips w composerze,
  - render attachment metadata i badge `edited` w user message,
  - banner lub affordance dla edit mode,
  - pending queued message podczas aktywnego streamu.
- test manualny:
  - wybrać plik i wysłać wiadomość,
  - zedytować starą wiadomość z plikiem,
  - podczas długiego streamu wysłać kolejną wiadomość,
  - sprawdzić refetch i zniknięcie lokalnych placeholderów.

## Handoff: planner

Done:
- Zdefiniowano frontendowy scope dla attachments, edit mode i queue UX.
- Wklejono backendowy kontrakt potrzebny do implementacji bez czytania drugiego repo.

Contract:
- Frontend używa multipart tam, gdzie pojawiają się pliki.
- Queue jest warstwą UX nad backendowym mailboxem, a transcript pozostaje kanoniczny po refetchu.

Next role:
- `manfred_frontend`

Risks:
- Nowa ścieżka HTTP dla multipart + SSE.
- Utrzymanie spójności overlay po rewindzie.
- Czytelny UX przy wzajemnym wykluczaniu edit i queue.
