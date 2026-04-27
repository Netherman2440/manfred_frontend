# Session Widget Refresh Analysis

## Problem

Widget / widok sesji odswieza sie przy kazdym wyslaniu wiadomosci, nawet gdy uzytkownik nadal pozostaje w tej samej sesji.

## Ocena przyczyny

Problem wyglada na frontendowy i wynika z tego, ze `ComposerController` wymusza pelne odswiezenie stanu sesji zamiast aktualizowac tylko lokalny stan streamu.

Najmocniejsze punkty:
- w trakcie streamu, juz na `ChatSessionStartedStreamEvent`, frontend robi:
  - `select(sessionId)`
  - `invalidate(sessionsListProvider)`
  - `invalidate(sessionDetailsProvider)`
- po zakonczeniu streamu robi to ponownie w `_reconcileAfterStream(...)`
- to oznacza co najmniej dwa cykle przebudowy / refetchu na jeden message flow

## Konkretne miejsca w kodzie

### 1. Stream start od razu wymusza refetch

`manfred/lib/features/chat/application/composer_controller.dart`

W `ChatSessionStartedStreamEvent`:
- `select(sessionId)` na `selectedSessionProvider`
- `invalidate(sessionsListProvider)`
- `invalidate(sessionDetailsProvider)`

Aktualne miejsce:
- `manfred/lib/features/chat/application/composer_controller.dart:169`

### 2. Po streamie jest drugi refresh tej samej sesji

W `_reconcileAfterStream(...)`:
- znow `select(sessionId)`
- fetch listy sesji
- na koncu znow:
  - `invalidate(sessionsListProvider)`
  - `invalidate(sessionDetailsProvider)`

Aktualne miejsce:
- `manfred/lib/features/chat/application/composer_controller.dart:214`

### 3. `select(sessionId)` przebudowuje nawet te sama sesje

`SelectedSessionController.select()` zawsze ustawia nowy obiekt stanu:

- `manfred/lib/features/sessions/application/selected_session_provider.dart:18`

Nie ma guardu typu:
- jesli `state.sessionId == sessionId`, to nic nie rob

W praktyce oznacza to, ze nawet ponowne wybranie juz aktywnej sesji moze notyfikowac watcherow i odpalic kolejne rebuildy.

### 4. Workspace obserwuje wszystko naraz

`ChatWorkspacePage` obserwuje jednoczesnie:
- `selectedSessionProvider`
- `sessionsListProvider`
- `sessionDetailsProvider`
- `composerControllerProvider`

Czyli kazda z powyzszych zmian moze przepchnac rebuild calego workspace.

Aktualne miejsce:
- `manfred/lib/ui/screens/chat_workspace/chat_workspace_page.dart:23`

## Wniosek

Najbardziej prawdopodobna przyczyna jest taka:

Frontend traktuje stream jako moment do wielokrotnego synchronizowania kanonicznego stanu z backendem, zamiast trzymac stabilny selection state i odswiezac dane tylko wtedy, gdy to naprawde konieczne.

Przez to ten sam flow robi:
1. zmiane selected session
2. invalidacje details
3. invalidacje listy
4. potem drugi raz to samo po reconcile

## Co warto sprawdzic / naprawic w nowym watku

- czy `select(sessionId)` powinno byc no-op, jesli sesja juz jest wybrana
- czy na `ChatSessionStartedStreamEvent` w ogole trzeba invalidowac `sessionDetailsProvider`
- czy da sie zostawic tylko jeden refetch po zakonczeniu streamu
- czy `sessionsListProvider` naprawde musi byc odswiezany przy kazdym message flow
- czy da sie ograniczyc rebuild `ChatWorkspacePage`, na przyklad przez rozdzielenie watcherow na mniejsze subtree

## Hipoteza glowna

Glowny winowajca to nie jeden pojedynczy widget, tylko kombinacja:
- `select()` bez guardu na te sama sesje
- wielokrotne `invalidate(...)` w `ComposerController`
- szeroki scope `watch(...)` w `ChatWorkspacePage`

## Plan implementacji

### 1. Zastapic refresh aktywnej sesji lokalnym dopisywaniem itemow

Kierunek:
- po starcie streamu nie odswiezac od razu `sessionDetailsProvider`
- utrzymywac lokalny, nadpisujacy stan aktywnej sesji po stronie frontendu
- kolejne delty / eventy z backendu dopisywac do tego stanu zamiast refetchowac cala sesje

Proponowany zakres:
- dodac lekka warstwe lokalnego nadpisania dla `SessionDetails`
- bazowac na danych z ostatniego fetchu, ale w trakcie streamu doklejac:
  - user message wyslana z composera
  - tymczasowa odpowiedz agenta skladana z delt
- po zakonczeniu streamu nie invalidowac automatycznie detailsow, tylko zostawic lokalny stan jako zrodlo prawdy do kolejnej jawnej synchronizacji

Uwagi projektowe:
- obecny `ComposerState` trzyma tylko `pendingUserMessage` i `streamingText`, wiec to wystarcza do renderu placeholdera, ale nie do stabilnego modelowania itemow sesji
- docelowo lepiej trzymac lokalne itemy w strukturze blizszej `SessionDetails.items`, zeby UI skladal widok z jednego modelu zamiast z fetchu plus specjalnego overlayu streamingu
- minimalny krok moze polegac na wprowadzeniu provider / kontrolera typu `activeSessionOverlay`, ktory:
  - po `ChatSessionStartedStreamEvent` inicjalizuje overlay dla sesji
  - dopisuje item usera
  - aktualizuje ostatni item odpowiedzi agenta na podstawie delt
  - po `done` finalizuje stan bez invalidate

### 2. Po pierwszym `session_id` dodac nowa sesje do listy lokalnie

Kierunek:
- dla nowej rozmowy, kiedy pierwszy raz dostajemy `session_id`, nie czekac na `invalidate(sessionsListProvider)`
- od razu wstawic nowy wpis do lokalnego stanu listy sesji

Proponowany zakres:
- dodac lokalny stan listy sesji albo overlay dla `sessionsListProvider`
- na `ChatSessionStartedStreamEvent`, jesli przed wysylka `selection.sessionId == null`, utworzyc nowy `SessionListEntry` i dodac go do listy
- nowy wpis powinien miec:
  - `id` z eventu
  - `createdAt` / `updatedAt` ustawione lokalnie na czas utworzenia
  - roboczy `title == null`, zeby UI pokazalo fallback czasowy
  - sensowny `rootAgentName` / `rootAgentId`, jesli sa juz znane

Efekt:
- po pierwszej wiadomosci nowa sesja od razu pojawia sie na liscie bez pelnego refetchu
- selection moze przelaczyc sie na nowy `sessionId`, ale sama lista nie musi byc invalidowana

### 3. `select(sessionId)` powinno byc no-op dla aktywnej sesji

Kierunek:
- ograniczyc niepotrzebne rebuildu juz na poziomie selekcji

Proponowany zakres:
- w `SelectedSessionController.select()` dodac guard:
  - jesli `state.sessionId == sessionId` i `state.isDraft == false`, nic nie rob

Efekt:
- samo ponowne wybranie tej samej sesji nie bedzie rozglaszac nowego stanu
- usunie to czesc zbednych przebudow niezaleznie od dalszych zmian w streamingu

### 4. Zmienic fallback title z `Untitled session` na date i godzine sesji

Kierunek:
- fallback powinien byc deterministyczny i oparty o dane sesji, nie o staly placeholder tekstowy

Proponowany zakres:
- zmienic `displayTitle` w:
  - `manfred/lib/features/sessions/domain/session_list_entry.dart`
  - `manfred/lib/features/sessions/domain/session_details.dart`
- zamiast `'Untitled session'` zwracac sformatowane `createdAt` sesji, np. `27.04.2026 14:35`

Uwagi projektowe:
- dobrze trzymac ten fallback w warstwie domenowej, bo juz teraz z niego korzystaja mappery listy i widoku sesji
- dzieki temu UI nie musi znac dodatkowej logiki fallbacku

### 5. Synchronizacja koncowa tylko jako kontrolowany fallback

Kierunek:
- pelny fetch zostawic jako mechanizm naprawczy, nie domyslny etap kazdego wyslania wiadomosci

Proponowany zakres:
- usunac automatyczne `invalidate(sessionsListProvider)` i `invalidate(sessionDetailsProvider)` z:
  - `ChatSessionStartedStreamEvent`
  - `_reconcileAfterStream(...)`
- ewentualny fetch zostawic tylko:
  - po bledzie, gdy lokalny stan moze byc niespojny
  - przy recznym retry
  - przy wejsciu w sesje, ktora nie ma jeszcze danych lokalnych

## Kolejnosc wdrozenia

1. Dodac guard w `select(sessionId)`.
2. Wprowadzic lokalny stan / overlay dla listy sesji.
3. Wprowadzic lokalny stan / overlay dla aktywnej sesji i dopisywania itemow.
4. Usunac automatyczne invalidate z flow streamu.
5. Zmienic fallback `displayTitle` na date i godzine.
6. Dopisac testy widgetowe dla:
   - nowej sesji pojawiajacej sie bez refetchu
   - braku refreshu aktywnej sesji przy streamie
   - fallbacku tytulu opartego o `createdAt`
