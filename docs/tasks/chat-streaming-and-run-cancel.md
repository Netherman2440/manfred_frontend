# Chat Streaming And Run Cancel

## Cel

Repo-local celem frontendu jest przejscie z prostego request-response na UX oparty o:
- streaming odpowiedzi w aktywnym workspace,
- lokalny stan generowania,
- przycisk `Stop` podpiety do backendowego `cancel`,
- pojednanie stanu przez refetch po zakonczeniu streamu.

Ta specyfikacja jest self-contained i zawiera backendowy kontrakt potrzebny frontendowi.

## Kontekst lokalny

Stan obecny frontendu:
- `HttpChatRepository.sendMessage(...)` zawsze wysyla `stream: false` w [chat_repository.dart](../../manfred/lib/features/chat/data/chat_repository.dart),
- `ManfredApiClient` obsluguje tylko `getJson` i `postJson` w [manfred_api_client.dart](../../manfred/lib/core/api/manfred_api_client.dart),
- `ComposerController` po mutacji robi `invalidate(...)` i odtwarza stan dopiero z kolejnego fetchu w [composer_controller.dart](../../manfred/lib/features/chat/application/composer_controller.dart),
- UI workspace renderuje gotowy snapshot sesji z providers session details/list, ale nie ma lokalnego modelu aktywnego streamu,
- domena sesji zna statusy z list/details, w tym `cancelled`, ale chat mutation result nie jest powiazany ze streamingiem.

Powod tej zmiany teraz:
- backend potrafi juz zwracac SSE dla `chat/completions`,
- bez klienta SSE uzytkownik nadal nie widzi pracy agenta na zywo,
- `Stop` ma sens produktowy dopiero przy streamingu.

## Scope

In-scope:
- klient SSE dla `POST /chat/completions` z `stream=true`,
- lokalny state machine aktywnego runu dla workspace,
- render czesciowej odpowiedzi asystenta podczas streamu,
- przycisk `Stop` wywolywany tylko dla aktywnego runu root agenta,
- integracja z backendowym `POST /chat/agents/{agent_id}/cancel`,
- refetch sesji i szczegolow po:
  - `done`
  - `error`
  - `cancel`
  - naturalnym zamknieciu streamu
- testy widgetowe / application-layer dla nowego flow.

Out-of-scope:
- wysylanie kolejnej wiadomosci podczas aktywnego streamu,
- lokalne wznowienie `waiting` bez refetchu,
- redesign transcriptu niezwiazany bezposrednio ze streamingiem,
- offline support i reconnect streamu,
- kolejkowanie albo auto-retry po cancel.

## Backend contract needed by frontend

`POST /api/v1/chat/completions`
- request:
  - ten sam payload co dzisiaj,
  - `stream=true` aktywuje SSE,
- eventy SSE:
  - `text_delta`
  - `text_done`
  - `function_call_delta`
  - `function_call_done`
  - `done`
  - `error`

Wazna zasada frontendowa:
- SSE sluzy do renderowania odpowiedzi na zywo,
- stan kanoniczny transcriptu nadal pochodzi z backendowego refetchu:
  - listy sesji
  - szczegolow sesji

`POST /api/v1/chat/agents/{agent_id}/cancel`
- endpoint zatrzymuje aktywny run,
- zwraca `ChatResponse`,
- `status` moze byc:
  - `cancelled`
  - albo juz istniejacy stan terminalny, jesli run skonczyl sie przed obsluga requestu.

`ChatResponse.status`
- musi byc obslugiwany przez frontend jako:
  - `completed`
  - `waiting`
  - `failed`
  - `cancelled`

## Moduly do zmiany

API client:
- `manfred/lib/core/api/manfred_api_client.dart`
- ewentualnie nowy pomocniczy modul SSE, np. `manfred/lib/core/api/sse_client.dart`

Chat data/domain:
- `manfred/lib/features/chat/data/chat_repository.dart`
- `manfred/lib/features/chat/data/chat_dto.dart`
- `manfred/lib/features/chat/domain/chat_mutation_result.dart`
- nowy model eventow / stanu streamu, jesli potrzebny

Application layer:
- `manfred/lib/features/chat/application/composer_controller.dart`
- ewentualnie nowy controller/provider dla aktywnego streamu i cancel
- `manfred/lib/features/sessions/application/session_details_provider.dart`
- `manfred/lib/features/sessions/application/sessions_list_provider.dart`

UI:
- `manfred/lib/ui/screens/chat_workspace/chat_workspace_page.dart`
- `manfred/lib/ui/screens/chat_workspace/controls/composer_mock.dart`
- `manfred/lib/ui/screens/chat_workspace/conversation/...` dla czesciowej wiadomosci agenta albo stanu generowania

Testy:
- `manfred/test/widget_test.dart`
- nowe testy application layer / widget dla streaming + stop

## Oczekiwane zachowanie

### Start streamu

1. User wysyla wiadomosc.
2. Frontend uruchamia request `chat/completions` z `stream=true`.
3. UI przechodzi w stan generowania:
   - composer blokuje ponowny send,
   - widoczny jest `Stop`,
   - transcript pokazuje tymczasowy, narastajacy output asystenta.

### Przetwarzanie eventow

- `text_delta` dopisuje tekst do tymczasowej odpowiedzi,
- `function_call_*` moze byc ignorowane w pierwszym kroku wizualnym albo logowane do stanu technicznego; stan kanoniczny i tak przyjdzie po refetchu,
- `error` konczy stream i prowadzi do refetchu oraz komunikatu bledu,
- `done` oznacza koniec transportu, ale frontend nadal refetchuje sesje dla finalnego stanu.

### Cancel

1. User klika `Stop`.
2. Frontend wysyla `POST /chat/agents/{agent_id}/cancel`.
3. UI przechodzi w stan "stopping", zeby nie dopuscic do kolejnych akcji.
4. Po potwierdzeniu albo zakonczeniu streamu frontend robi refetch sesji i transcriptu.
5. Lokalny stan przechodzi do idle.

### Reconciliation

Po kazdym zakonczeniu streamu frontend:
- odswieza `sessionsListProvider`,
- odswieza `sessionDetailsProvider`,
- czysci lokalny tymczasowy output,
- przyjmuje stan kanoniczny z backendu:
  - `completed`
  - `waiting`
  - `failed`
  - `cancelled`

## Decyzje architektoniczne

- Nie probujemy skladac finalnego transcriptu tylko z eventow SSE.
- Stream jest warstwa UX, a nie nowym source of truth dla historii sesji.
- `Stop` pojawia sie tylko dla aktywnego runu root agenta widocznego w workspace.
- Fallback request-response pozostaje wspierany, dopoki rollout nie zostanie uznany za stabilny.

## Edge cases

- stream konczy sie zanim user kliknie `Stop`: frontend przyjmuje wynik terminalny po refetchu i nie pokazuje falszywego bledu,
- `cancel` wraca po tym, jak run juz sie zakonczyl: frontend tylko reconciliuje stan z backendem,
- zerwanie sieci podczas streamu: UI pokazuje blad, czysci lokalny stan i robi refetch,
- `waiting` po streamie: frontend nie pokazuje juz `Stop`, tylko wraca do obecnego flow `deliver`.

## Acceptance Criteria

- po wyslaniu wiadomosci odpowiedz pojawia sie na zywo w transcriptcie,
- podczas generowania composer nie pozwala na drugi send do tej samej sesji,
- podczas generowania widoczny jest przycisk `Stop`,
- klikniecie `Stop` prowadzi do stanu zgodnego z backendem i nie zostawia UI w nieskonczonym loadingu,
- po zakonczeniu streamu frontend zawsze odswieza sesje i szczegoly,
- UI poprawnie rozpoznaje status `cancelled`,
- obecny flow `waiting -> deliver` nadal dziala po refetchu.

## Test plan

- testy jednostkowe:
  - mapowanie eventow SSE do lokalnego stanu streamu,
  - przejscia `idle -> streaming -> stopping -> idle`,
  - obsluga statusu `cancelled`.
- testy widgetowe:
  - render czesciowej odpowiedzi,
  - widocznosc `Stop` tylko podczas streamu,
  - refetch po naturalnym zakonczeniu,
  - refetch po cancel.
- test manualny:
  - wyslac dluzsza wiadomosc i obserwowac delty,
  - kliknac `Stop`,
  - sprawdzic finalny transcript po odswiezeniu danych,
  - sprawdzic wejscie w `waiting` po streamie bez regresji dla `deliver`.

## Handoff: planner

Done:
- Zdefiniowano frontendowy scope dla SSE, lokalnego stanu generowania i akcji `Stop`.
- Wklejono backendowy kontrakt niezbedny do implementacji bez czytania drugiego repo.

Contract:
- Frontend uzywa SSE tylko do UX, a finalny stan transcriptu bierze z refetchu.
- `Stop` jest podpiety do backendowego endpointu `cancel`.

Next role:
- `manfred_frontend`

Risks:
- Potrzeba dobrze odseparowac tymczasowy stan streamu od kanonicznych danych sesji.
- Nietrywialne jest unikniecie migotania UI przy przejsciu z local-stream state do refetchowanego transcriptu.
