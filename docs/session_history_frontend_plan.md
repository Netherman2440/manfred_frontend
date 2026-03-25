# Plan implementacji historii sesji we frontendzie

## Cel

Dodać do frontendu możliwość:

- wyświetlenia listy historycznych sesji,
- wejścia w szczegóły wybranej sesji,
- pokazania pełnego przebiegu sesji razem ze wszystkimi itemami i attachmentami,
- oddzielenia historii z backendu od lokalnego stanu bieżącego chatu.

## Stan obecny

Frontend ma dziś:

- widok landing page,
- widok `'/chat'`,
- lokalny stan aktywnej rozmowy,
- zapis aktywnej rozmowy w `localStorage`.

Braki:

- brak routingu pod listę sesji,
- brak routingu pod szczegóły sesji,
- brak klienta API dla historii,
- brak rozdzielenia `live chat` od `history view`,
- historia nie pochodzi z backendu.

## Założenie projektowe

Rekomendowany kontrakt z backendu:

- lista sesji przez osobny endpoint,
- szczegóły sesji zwracane jako gotowe `entries[]` zbliżone do obecnego `ChatEntry[]`.

To pozwala wykorzystać istniejące komponenty:

- renderer wiadomości usera,
- renderer attachmentów,
- `AgentResponseBlock` dla odpowiedzi agenta.

## Docelowe widoki

### 1. Lista sesji

Nowa trasa:

- `'/sessions'`

Widok powinien pokazywać:

- `summary` lub fallback title,
- `updatedAt`,
- `status`,
- opcjonalnie `sessionId`,
- akcję wejścia w szczegóły.

### 2. Szczegóły sesji

Nowa trasa:

- `'/sessions/:sessionId'`

Widok powinien pokazywać:

- nagłówek sesji,
- status,
- daty,
- pełny feed `entries[]`,
- wszystkie attachmenty przypięte do wpisów,
- wszystkie itemy odpowiedzi agenta.

### 3. Widok live chatu

Obecny `'/chat'` zostaje bez zmiany celu:

- to jest ekran aktywnej rozmowy,
- nie powinien być źródłem historii dla starszych sesji.

## Etapy implementacji

### Etap 1. Rozszerzyć routing aplikacji

Dodać nowe trasy:

- `'/sessions'`
- `'/sessions/:sessionId'`

Minimalny zakres:

- aktualizacja lokalnego routera o nowe widoki,
- obsługa `pushState`,
- obsługa `popstate`,
- helpery do przechodzenia między listą, szczegółem i chatem.

Jeśli obecny ręczny routing zacznie rosnąć za bardzo, warto rozważyć prostą migrację do `react-router`, ale nie jest to wymagane na start.

### Etap 2. Dodać typy historii sesji

W `src/types/` dodać typy dla:

- `SessionListItem`,
- `SessionListResponse`,
- `SessionDetailResponse`,
- ewentualnie metadanych szczegółu sesji.

Jeśli backend zwróci `entries[]` kompatybilne z obecnym modelem, można reuse'ować:

- `ChatEntry`,
- `ChatAttachment`,
- `AgentResponse`.

### Etap 3. Dodać klienta API do historii

W `src/lib/chat-api.ts` albo w osobnym module dodać:

- `fetchSessionList()`
- `fetchSessionDetail(sessionId)`

Wymagania:

- wspólna obsługa błędów jak w obecnym kliencie API,
- walidacja payloadu,
- normalizacja dat i opcjonalnych pól,
- brak zależności od `localStorage`.

### Etap 4. Zbudować widok listy sesji

Nowy komponent lub zestaw komponentów:

- `SessionListPage`
- `SessionListItemCard`

Funkcje widoku:

- loading state,
- error state,
- pusta lista,
- kliknięcie w rekord otwiera szczegóły,
- opcjonalne oznaczenie bieżącej aktywnej sesji.

### Etap 5. Zbudować widok szczegółu sesji

Nowy komponent:

- `SessionDetailPage`

Widok powinien:

- pobierać dane po `sessionId`,
- renderować `entries[]` w tej samej kolejności co feed,
- wykorzystywać istniejące renderery wpisów,
- mieć własny loading i error state.

Rekomendacja:

- wydzielić wspólny komponent feedu, tak żeby `ChatPage` i `SessionDetailPage` współdzieliły renderowanie wpisów.

### Etap 6. Rozdzielić stan live chatu od historii

Należy jasno oddzielić dwa źródła danych:

- `live chat` z `localStorage` i bieżącego request flow,
- `session history` pobierane z backendu.

`localStorage` powinno zostać tylko dla:

- draftu,
- aktywnej lokalnej sesji,
- ewentualnego cache ostatniego ekranu.

Nie powinno być wykorzystywane do budowy listy historii.

### Etap 7. Dodać nawigację między widokami

Wymagane linki i akcje:

- z chatu do listy sesji,
- z listy sesji do szczegółu,
- ze szczegółu z powrotem do listy,
- opcjonalnie ze szczegółu do `'/chat'`, jeśli użytkownik chce wznowić rozmowę.

Wariant rekomendowany:

- jeśli użytkownik otworzy szczegóły bieżącej aktywnej sesji, można dać akcję `open in chat`.

### Etap 8. Obsłużyć odświeżanie i synchronizację

Po wysłaniu wiadomości w live chacie:

- sesja powinna być widoczna na liście po kolejnym wejściu,
- szczegóły tej sesji powinny dać się pobrać z backendu niezależnie od lokalnego stanu.

Opcjonalnie później:

- manualny `refresh`,
- polling,
- optimistic refresh listy po nowej turze.

### Etap 9. Testy

Do dodania:

- render listy sesji,
- render pustej listy,
- render błędu listy,
- render szczegółu sesji,
- render pełnego feedu z attachmentami i agent response,
- nawigacja między trasami,
- zachowanie przy błędnym `sessionId`.

## Proponowana struktura zmian

Przykładowe obszary:

- `src/App.tsx` lub nowy moduł routera
- `src/lib/chat-api.ts` lub osobny `session-history-api.ts`
- `src/types/chat.ts` lub osobne `session-history.ts`
- nowe komponenty widoków historii

Rekomendacja:

- nie dopisywać całej historii bezpośrednio do `App.tsx`,
- wydzielić osobne page components dla czytelności.

## Proponowana kolejność prac

1. Dodać typy API historii.
2. Dodać klienta API historii.
3. Dodać nowy routing.
4. Zbudować listę sesji.
5. Zbudować szczegóły sesji.
6. Wydzielić wspólny renderer feedu.
7. Dodać testy i dopracować loading/error UX.

## Ryzyka

- jeśli backend zwróci tylko surowe `items[]`, frontendowy zakres prac istotnie wzrośnie,
- ręczny routing w `App.tsx` stanie się trudniejszy do utrzymania przy kolejnych widokach,
- bez wspólnego komponentu feedu łatwo o duplikację renderowania między live chatem i historią.

## Rekomendacja końcowa

Frontend powinien traktować historię sesji jako osobny feature oparty o dane z backendu, a nie rozszerzenie obecnego `localStorage`.

Najlepszy wariant implementacyjny:

- backend zwraca gotowe `entries[]`,
- frontend dodaje listę i szczegóły sesji,
- obecny renderer feedu zostaje współdzielony między live chatem i historią.
