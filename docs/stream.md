# Plan wdrożenia stream response i pełnego timeline'u odpowiedzi

## Cel

Chcemy, żeby `manfred_frontend`:

- renderował odpowiedź asystenta w trakcie generowania,
- pokazywał cały jawny przebieg tury, a nie tylko końcowy tekst,
- wyświetlał również `tool call` oraz wynik działania narzędzia,
- zachował zgodność z obecnym modelem sesji i attachmentów.

W tym dokumencie przez "przebieg dedukcji" rozumiem jawny timeline wykonania agenta:

- wiadomości asystenta,
- wywołania narzędzi,
- rezultaty narzędzi,
- status zakończenia tury.

Nie rekomenduję eksponowania ukrytego chain-of-thought providera. Jeśli kiedyś pojawi się potrzeba pokazywania reasoning, powinno to być osobne, świadomie zaprojektowane pole, a nie surowy strumień wewnętrznych tokenów modelu.

## Ocena aktualnego stanu

Wniosek: frontend nie jest dziś gotowy na ten zakres. Backend również nie jest jeszcze gotowy na prawdziwy streaming.

### Frontend

Obecna implementacja:

- `src/lib/chat-api.ts`
  - `sendChatCompletion(...)` robi zwykły `fetch`, potem `await response.json()`,
  - zwraca `message` złożone przez `collectOutputText(output).join(...)`,
  - ignoruje strukturę timeline'u i redukuje odpowiedź do jednego stringa.
- `src/types/chat.ts`
  - model stanu to tylko `ChatMessage { role, content, attachments }`,
  - nie ma typu dla `tool_call`, `tool_result`, stanu streamingu ani turn-level timeline'u.
- `src/App.tsx`
  - podczas czekania renderowany jest tylko statyczny typing indicator,
  - po zakończeniu requestu dopisywana jest jedna wiadomość asystenta,
  - na `abort` usuwana jest optymistycznie dodana wiadomość usera zamiast zachować stan tury.
- `src/lib/storage.ts`
  - local storage zapisuje wyłącznie `messages[]`,
  - nie ma miejsca na zapis eventów, turnów ani elementów pośrednich.

### Backend

Obecna implementacja:

- `manfred/src/app/api/v1/chat/api.py`
  - wystawia tylko zwykły `POST /api/v1/chat/completions`,
  - brak `StreamingResponse`, brak `text/event-stream`, brak eventów.
- `manfred/src/app/providers/openai.py`
  - provider ma tylko synchroniczne `generate(...)`,
  - brak metody streamującej odpowiedź providera.
- `manfred/src/app/services/chat_service.py`
  - odpowiedź API jest budowana dopiero po zakończeniu całego biegu agenta,
  - serializowane są tylko:
    - wiadomości asystenta,
    - `function_call`,
  - `FUNCTION_CALL_OUTPUT` jest zapisywany w runtime, ale nie trafia do API.
- `manfred/src/app/runtime/runner.py`
  - runner zapisuje do repo zarówno `FUNCTION_CALL`, jak i `FUNCTION_CALL_OUTPUT`,
  - to znaczy: dane potrzebne do pełnego timeline'u częściowo już istnieją, ale nie są wystawiane przez API.

## Co trzeba zmienić architektonicznie

### 1. Kanoniczny model odpowiedzi

Zamiast redukować wszystko do jednego `message`, odpowiedź jednej tury powinna mieć kanoniczny, uporządkowany timeline.

Rekomendacja:

- zostawić `message` wyłącznie jako pole pochodne albo usunąć je z nowej warstwy UI,
- dodać `timeline[]` jako podstawowe źródło prawdy,
- zachować `output[]` tylko jeśli potrzebna jest kompatybilność wstecz.

Przykładowy kształt:

```json
{
  "sessionId": "sess_123",
  "agentId": "agent_123",
  "status": "completed",
  "timeline": [
    {
      "id": "item_10",
      "sequence": 10,
      "type": "assistant_message",
      "text": "Najpierw sprawdzę dane..."
    },
    {
      "id": "item_11",
      "sequence": 11,
      "type": "tool_call",
      "callId": "call_1",
      "name": "search_docs",
      "arguments": { "query": "..." }
    },
    {
      "id": "item_12",
      "sequence": 12,
      "type": "tool_result",
      "callId": "call_1",
      "name": "search_docs",
      "output": { "ok": true, "items": [] },
      "isError": false
    },
    {
      "id": "item_13",
      "sequence": 13,
      "type": "assistant_message",
      "text": "Na podstawie wyników..."
    }
  ]
}
```

Minimalny zakres timeline'u dla obecnego celu:

- `assistant_message`
- `tool_call`
- `tool_result`

Opcjonalnie później:

- `reasoning_summary`
- `agent_waiting`
- `agent_resumed`

### 2. Streaming po `fetch`, nie po `EventSource`

Ponieważ endpoint czatu jest `POST` i wymaga body JSON, frontend powinien czytać stream przez `fetch(...).body`.

Rekomendacja:

- transport: SSE po `POST /api/v1/chat/completions?stream=true`,
- nagłówek odpowiedzi: `Content-Type: text/event-stream`,
- parser eventów po stronie frontu czytany z `ReadableStream`.

`EventSource` odpada jako główny klient, bo nie obsługuje sensownie `POST` z body.

### 3. Jeden kontrakt semantyczny dla stream i non-stream

Najważniejsza zasada: eventy streamingu i końcowy snapshot JSON muszą opisywać ten sam model.

Czyli:

- stream emituje eventy odpowiadające elementom `timeline`,
- response bez streamingu zwraca finalny `timeline[]`,
- frontend używa jednej normalizacji stanu niezależnie od trybu transportu.

## Rekomendowany kontrakt eventów

### Eventy SSE

Minimalny zestaw:

```text
event: turn.started
data: {"sessionId":"sess_123","agentId":"agent_123","turnId":"turn_1"}

event: assistant.message.started
data: {"id":"msg_1","sequence":10}

event: assistant.message.delta
data: {"id":"msg_1","delta":"Najpierw "}

event: assistant.message.delta
data: {"id":"msg_1","delta":"sprawdzę dane..."}

event: assistant.message.completed
data: {"id":"msg_1","text":"Najpierw sprawdzę dane..."}

event: tool.call.started
data: {"id":"item_11","sequence":11,"callId":"call_1","name":"search_docs","arguments":{"query":"..."}}

event: tool.call.completed
data: {"id":"item_12","sequence":12,"callId":"call_1","name":"search_docs","output":{"ok":true,"items":[]},"isError":false}

event: turn.completed
data: {"status":"completed"}
```

W przypadku błędu:

```text
event: turn.failed
data: {"status":"failed","error":"..."}
```

### Zasady semantyczne

- `assistant.message.delta` zawsze odnosi się do wcześniej utworzonego `assistant.message.started`.
- `tool.call.started` pojawia się, gdy runner zapisał lub rozpoznał `FUNCTION_CALL`.
- `tool.call.completed` albo `tool.call.failed` pojawia się po wykonaniu narzędzia.
- `turn.completed` jest ostatnim eventem przy sukcesie.
- `turn.failed` jest ostatnim eventem przy błędzie.

## Plan implementacji

### Etap 1. Ujednolicić odpowiedź synchroniczną backendu

Cel: zanim pojawi się streaming, backend musi już umieć zwrócić pełny snapshot tury.

Zmiany:

- `manfred/src/app/domain/chat.py`
  - rozszerzyć typy odpowiedzi o `tool_result`,
  - najlepiej dodać osobny typ `ChatTimelineItem`.
- `manfred/src/app/api/v1/chat/schema.py`
  - dodać payload dla `tool_result`,
  - dodać `timeline` do `ChatResponse`.
- `manfred/src/app/services/chat_service.py`
  - serializować `FUNCTION_CALL_OUTPUT`,
  - budować odpowiedź według rzeczywistej kolejności `sequence`,
  - nie gubić itemów pośrednich.

Akceptacja etapu:

- zwykły `POST /api/v1/chat/completions` zwraca pełny `timeline[]`,
- `timeline[]` zawiera `assistant_message`, `tool_call`, `tool_result`,
- kolejność odpowiada `Item.sequence`.

### Etap 2. Dodać backendowy stream SSE

Cel: API ma emitować eventy w trakcie pracy agenta, a nie dopiero po zakończeniu.

Zmiany:

- `manfred/src/app/providers/openai.py`
  - dodać metodę streamującą dla providera,
  - mapować eventy providera na neutralne eventy runtime.
- warstwa provider/domain
  - dodać typy eventów streamingu,
  - nie wiązać kontraktu eventów z konkretnym providerem.
- `manfred/src/app/runtime/runner.py`
  - wprowadzić ścieżkę `run_agent_stream(...)`,
  - emitować eventy:
    - start wiadomości asystenta,
    - delty tekstu,
    - start tool calla,
    - koniec tool calla,
    - zakończenie lub błąd tury.
- `manfred/src/app/services/chat_service.py`
  - dodać metodę typu `stream_chat(...)`,
  - spiąć `prepare_chat_turn(...)` z eventami streamingu.
- `manfred/src/app/api/v1/chat/api.py`
  - obsłużyć `stream=true` i zwracać `StreamingResponse`.

Uwagi:

- nawet jeśli provider nie da pełnych delt dla tooli, backend nadal może emitować eventy na granicach runnera,
- to wystarczy, żeby UI pokazał pełny przebieg działania.

Akceptacja etapu:

- request z `stream=true` zwraca `text/event-stream`,
- frontend może dostać delty tekstu i eventy narzędzi przed końcem całej tury.

### Etap 3. Zmienić model stanu frontendu

Cel: UI musi przechowywać nie tylko wiadomości, ale cały przebieg tury.

Zmiany:

- `manfred_frontend/src/types/chat.ts`
  - dodać typy:
    - `ChatTurn`
    - `ChatTimelineItem`
    - `AssistantMessageItem`
    - `ToolCallItem`
    - `ToolResultItem`
    - statusy streamingu itemów i tury
- `manfred_frontend/src/lib/storage.ts`
  - migrować zapis z `messages[]` do `turns[]` albo `timeline[]`,
  - zachować kompatybilny fallback dla starych danych z local storage.

Rekomendacja modelu UI:

```ts
type ChatTimelineItem =
  | { id: string; type: 'user_message'; text: string; createdAt: string; attachments?: ChatAttachment[] }
  | { id: string; type: 'assistant_message'; text: string; createdAt: string; status: 'streaming' | 'completed' }
  | { id: string; type: 'tool_call'; callId: string; name: string; arguments: Record<string, unknown>; createdAt: string; status: 'running' | 'completed' | 'failed' }
  | { id: string; type: 'tool_result'; callId: string; name: string; output: unknown; isError: boolean; createdAt: string }
```

To wystarczy do renderu pełnego timeline'u bez mieszania semantyki "message bubble" i "event runtime".

### Etap 4. Dodać frontendowy klient streamingu

Cel: frontend ma czytać SSE i aktualizować stan inkrementalnie.

Zmiany:

- `manfred_frontend/src/lib/chat-api.ts`
  - zostawić `sendChatCompletion(...)` dla fallbacku JSON,
  - dodać `streamChatCompletion(...)`,
  - dodać parser eventów SSE na `ReadableStream`,
  - dodać normalizację eventów do wspólnego modelu domenowego.

Rekomendacja API klienta:

```ts
streamChatCompletion(payload, {
  signal,
  onEvent(event) {
    // update UI state
  },
})
```

Ważne:

- nie sklejać już `output[]` do jednego `message`,
- eventy mają zasilać stan po kolei,
- końcowy snapshot z `turn.completed` powinien domknąć stan tury.

### Etap 5. Przebudować render feedu

Cel: UI ma pokazywać timeline, nie tylko listę wiadomości.

Zmiany:

- `manfred_frontend/src/App.tsx`
  - zastąpić `messages[]` strukturą timeline'u,
  - podczas wysyłki dodać optymistycznie item usera,
  - tworzyć placeholder dla aktywnej wiadomości asystenta dopiero na event `assistant.message.started`,
  - aktualizować tekst po `assistant.message.delta`,
  - dopisywać karty `tool_call` i `tool_result`.
- dodać osobne komponenty, np.:
  - `TimelineFeed`
  - `AssistantMessageRow`
  - `ToolCallRow`
  - `ToolResultRow`

Rekomendacja UX:

- wiadomości usera i asystenta zostają jako bubble,
- `tool_call` i `tool_result` pokazywać jako bardziej techniczne, zwijane bloki,
- argumenty i output domyślnie skrócone, z możliwością rozwinięcia JSON-a,
- aktywny tool oznaczać statusem `running`.

### Etap 6. Poprawić semantykę `abort`

Obecnie `abort` usuwa wiadomość usera z feedu. Przy streamingu to będzie mylące.

Po zmianie:

- wiadomość usera powinna zostać w historii,
- aktywna tura powinna dostać status `cancelled` albo `interrupted`,
- częściowo wygenerowany tekst asystenta może zostać oznaczony jako przerwany,
- aktywny tool powinien mieć stan `cancelled` tylko jeśli backend rzeczywiście potwierdzi przerwanie.

### Etap 7. Testy

Backend:

- test snapshotu `timeline[]`,
- test obecności `tool_result`,
- test kolejności po `sequence`,
- test SSE:
  - event order,
  - `turn.failed`,
  - zachowanie przy `AbortSignal`.

Frontend:

- test parsera SSE,
- test reduktora stanu timeline'u,
- test renderu:
  - delta tekstu,
  - pojawienie się `tool_call`,
  - pojawienie się `tool_result`,
  - przerwanie streamu,
  - restore stanu z local storage.

## Kolejność wdrożenia

Najbezpieczniejsza kolejność:

1. Backend: dodać `timeline[]` do zwykłego JSON response.
2. Frontend: przejść z `messages[]` na `timeline[]`, ale jeszcze bez streamingu.
3. Backend: dodać SSE.
4. Frontend: dodać klient streamingu i inkrementalny render.
5. Dopiero na końcu usunąć stare uproszczenia typu `response.message`.

To minimalizuje ryzyko, bo UI najpierw nauczy się renderować pełny przebieg z gotowego snapshotu, a dopiero potem dostanie eventy live.

## Minimalne kryteria akceptacji

- Po wysłaniu wiadomości UI pokazuje:
  - wiadomość usera,
  - kolejne fragmenty odpowiedzi asystenta w trakcie generowania,
  - każdy `tool_call`,
  - wynik każdego toola.
- Po odświeżeniu strony rozmowa nadal pokazuje pełny przebieg ostatnich tur.
- Tryb non-stream i stream opisują tę samą strukturę danych.
- Brak redukcji całej odpowiedzi do jednego stringa.

## Szybka diagnoza

Jeśli chcesz to zrobić bez przepisywania wszystkiego naraz, najrozsądniej jest potraktować obecny frontend jako gotowy wizualnie, ale nie gotowy modelowo.

Największy brak nie leży w samym komponencie UI, tylko w tym, że:

- backend nie emituje streamu,
- backend nie zwraca jeszcze pełnego timeline'u,
- frontendowy stan ma zbyt wąski model danych.

Dlatego to jest zadanie "zmiany kontraktu + zmiany stanu UI", a nie tylko dodania spinnera czy podmiany `fetch`.
