# Plan: frontendowe wyświetlanie pełnego kontekstu odpowiedzi

## Cel

Na ten etap nie robimy jeszcze streamingu.

Cel jest prostszy:

- frontend ma przestać redukować odpowiedź do jednego stringa,
- ma wyświetlać wszystkie typy elementów zwróconych przez backend,
- ma być gotowy na:
  - `text`,
  - `reasoning`,
  - `function_call`,
  - `function_call_output`,
- user ma widzieć pełny przebieg odpowiedzi w jednej turze.

## Nomenklatura

W tym planie trzymamy się modelu domenowego:

- `User`
- `Session`
- `Agent`
- `Item`

To ważne, bo frontend ma być przygotowany nie tylko na "wiadomość asystenta", ale na render itemów należących do konkretnego agenta w ramach sesji usera.

## Wniosek

To da się przygotować głównie po stronie frontendu, ale z jednym zastrzeżeniem:

- frontend może od razu nauczyć się renderować wszystkie typy,
- jednak `reasoning` i `function_call_output` pojawią się w UI dopiero wtedy, gdy backend rzeczywiście zacznie je zwracać.

Innymi słowy:

- plan jest frontend-first,
- ale nie obiecuje magii tam, gdzie backend jeszcze nie wysyła danych.

## Co jest dziś

### Aktualny frontend

Obecnie:

- `src/lib/chat-api.ts` pobiera `output[]`, ale składa go do pojedynczego `message`,
- `src/types/chat.ts` zna tylko `ChatMessage { role, content, attachments }`,
- `src/App.tsx` renderuje jedną bubble usera i jedną bubble asystenta,
- wszystko poza tekstem asystenta jest de facto gubione.

To oznacza, że nawet jeśli backend zwróci dodatkowe itemy, obecne UI ich nie pokaże.

### Aktualny backend

Z kodu backendu wynika:

- dziś API zwraca `text` i `function_call`,
- runtime już zapisuje też `FUNCTION_CALL_OUTPUT`,
- `ItemType.REASONING` istnieje w domenie, ale nie widać jeszcze aktywnego użycia w payloadzie API.

Dlatego frontend powinien zostać przygotowany szerzej niż obecny kontrakt.

## Założenie projektowe

Frontend nie powinien już operować na "wiadomości asystenta jako stringu".

Zamiast tego odpowiedź powinna być renderowana jako lista `Item` należących do konkretnego `Agent`.

Na ten etap nadal możemy renderować to wizualnie jako jeden blok odpowiedzi asystenta, ale model danych powinien już być bliższy:

- `Session`
- `Agent`
- `Item[]`

Minimalny model:

```ts
type AgentItem =
  | {
      id: string
      type: 'text'
      text: string
    }
  | {
      id: string
      type: 'reasoning'
      text?: string
      summary?: string
      metadata?: Record<string, unknown>
    }
  | {
      id: string
      type: 'function_call'
      callId: string
      name: string
      arguments: Record<string, unknown>
    }
  | {
      id: string
      type: 'function_call_output'
      callId: string
      name?: string
      output: unknown
      isError?: boolean
    }
  | {
      id: string
      type: 'unknown'
      raw: unknown
    }
```

Kluczowa zasada:

- frontend ma być tolerancyjny,
- jeśli backend wyśle nowy albo nieznany typ, UI nie może go zgubić,
- zamiast tego powinien pokazać bezpieczny fallback `unknown`.

## Docelowy render jednej tury

### User message

Bez większych zmian:

- tekst usera,
- attachmenty,
- timestamp.

### Agent response block

Zamiast jednej markdown bubble:

- renderujemy blok odpowiedzi konkretnego `Agent`,
- w środku listę `AgentItem[]` w kolejności.

Przykład wizualny:

1. `text`
2. `reasoning`
3. `function_call`
4. `function_call_output`
5. `text`

To daje pełny kontekst bez mieszania semantyki "wiadomość" i "narzędzie".
Jednocześnie nie blokuje nas to na przyszłość, jeśli w jednej `Session` pojawi się więcej niż jeden `Agent`.

## Jak renderować poszczególne typy

### `text`

Render:

- jako obecny markdown bubble,
- dalej można użyć `AssistantMarkdown`.

To jest jedyny element, który powinien być renderowany jako klasyczna odpowiedź asystenta.

### `reasoning`

Render:

- jako zwijany blok techniczny,
- domyślnie zwinięty,
- label np. `reasoning`,
- zawartość jako plain text albo markdown, zależnie od kształtu danych.

Ważne:

- reasoning nie powinien wizualnie udawać finalnej odpowiedzi,
- lepiej potraktować go jako meta-warstwę lub "trace".

Jeśli backend kiedyś wyśle tylko skrót reasoning zamiast pełnego tekstu, komponent nadal pozostaje poprawny.

### `function_call`

Render:

- jako karta techniczna,
- nagłówek:
  - nazwa toola,
  - `callId`,
- body:
  - sformatowane `arguments`,
  - domyślnie skrócone,
  - z możliwością rozwinięcia JSON-a.

To powinno być czytelne, ale nie dominować całego feedu.

### `function_call_output`

Render:

- jako karta wyniku toola,
- powiązana wizualnie z `function_call` przez `callId`,
- jeśli `isError === true`, wyróżniona stanem błędu,
- `output` pokazywany jako:
  - JSON pretty print,
  - albo plain text, jeśli to string.

Jeśli `function_call_output` nie ma `name`, można go zlinkować po samym `callId`.

### `unknown`

Render:

- prosty blok developerski,
- label `unknown output item`,
- zrzut surowego payloadu.

To jest ważne, bo frontend ma przestać "zjadać" nowe typy danych.

## Zmiany w modelu danych frontendu

### 1. Rozszerzyć `src/types/chat.ts`

Obok `ChatMessage` dodać:

- `AgentItem`
- `AgentResponse`

Rekomendowany kierunek:

```ts
interface AgentResponse {
  id: string
  sessionId: string
  agentId: string
  parentAgentId?: string
  depth?: number
  role: 'assistant'
  createdAt: string
  items: AgentItem[]
}
```

oraz zmienić model rozmowy na:

```ts
type ChatEntry = ChatMessage | AgentResponse
```

To pozwoli:

- zostawić user message prostą,
- a jednocześnie nie wciskać tool calli do `content: string`.
- od razu zostawić miejsce na przyszłe `Agent`, także child agenty.

### 2. Nie gubić surowego `output[]`

`src/lib/chat-api.ts` powinno:

- przestać wyliczać `message` jako podstawowe pole,
- zwracać znormalizowane `items`,
- mapować znane typy,
- odkładać nieznane do `unknown`.

Rekomendacja:

- `message` można chwilowo zostawić jako pole pochodne wyłącznie dla kompatybilności,
- ale UI nie powinno już na nim polegać.

## Zmiany w warstwie API klienta

### Nowa normalizacja outputu

W `src/lib/chat-api.ts` dodać:

- parser `normalizeOutputItem(raw: unknown): AgentItem`,
- parser `normalizeAgentItems(rawOutput: unknown[]): AgentItem[]`.

Parser powinien obsłużyć co najmniej:

- `type === "text"`
- `type === "output_text"`
- `type === "reasoning"`
- `type === "function_call"`
- `type === "function_call_output"`

oraz fallback:

- `unknown`

### Tolerowanie wariantów backendowych

Warto przyjąć łagodną normalizację dla różnych kształtów pól, np.:

- `callId` lub `call_id`,
- `arguments` jako obiekt albo string JSON,
- `output` jako obiekt albo string,
- `text` jako string albo `{ value: string }`.

To ograniczy liczbę drobnych regresji przy zmianach po stronie backendu.

## Zmiany w UI

### Nowe komponenty

Rekomendowany podział:

- `src/components/AgentResponseBlock.tsx`
- `src/components/AgentItemView.tsx`
- `src/components/ReasoningBlock.tsx`
- `src/components/ToolCallCard.tsx`
- `src/components/ToolOutputCard.tsx`

Powód:

- obecny `App.tsx` już teraz ma za dużo odpowiedzialności,
- render różnych typów outputu stanie się nieczytelny, jeśli zostanie inline.

### Zachowanie feedu

W feedzie:

- user message zostaje `message-row--user`,
- agent response block dostaje `message-row--assistant`,
- w środku renderowana jest lista elementów outputu.

To zachowa obecny layout i styling, a jednocześnie rozszerzy semantykę.

### Powiązanie call -> output

Jeśli w jednej turze pojawi się:

- `function_call(callId=abc)`
- `function_call_output(callId=abc)`

to UI powinno pokazać to blisko siebie i po kolejności, bez dodatkowego grupowania w logice.

Czyli:

- bazowy porządek to kolejność `output[]`,
- nie sortujemy nic sztucznie na froncie,
- `callId` służy tylko do labeli i ewentualnych wizualnych powiązań.

## Ocena CopilotKit w tym projekcie

### Co już realnie używamy

W projekcie dziś używany jest tylko `Markdown` z `@copilotkit/react-ui`.

To jest sensowny reuse i warto go zostawić dla `text`.

### Co CopilotKit ma, ale nie daje nam od razu korzyści

W zainstalowanej wersji `1.54.0` widać:

- custom `AssistantMessage` / `UserMessage` w `@copilotkit/react-ui`,
- `message.generativeUI()` w komponentach wiadomości,
- hook `useRenderToolCall(...)` w `@copilotkit/react-core`,
- wzmianki w changelogu o wsparciu reasoning.

Problem:

- te prymitywy są zaprojektowane wokół CopilotKitowego modelu wiadomości i ich runtime,
- nasz frontend działa na własnym REST payloadzie z `manfred`,
- nie mamy podpiętego CopilotKit chat runtime ani ich message pipeline.

W praktyce oznacza to, że:

- nie opłaca się teraz przepinać całego feedu na CopilotKit tylko po to, żeby wyrenderować tool calle,
- bardziej opłaca się zbudować własny, prosty renderer oparty o nasz model danych.

### Rekomendacja

Na ten etap:

- zostawić CopilotKit `Markdown`,
- ewentualnie podpatrzeć ich wzorce UI i CSS,
- nie uzależniać renderu tool calli ani reasoning od CopilotKit runtime.

Krótko:

- gotowiec częściowy istnieje,
- ale koszt adaptera do naszego transportu jest większy niż zysk.

## Plan implementacji

### Etap 1. Rozszerzyć typy i storage

Zmiany:

- `src/types/chat.ts`
  - dodać `AgentItem`,
  - dodać `AgentResponse`,
  - zmienić model listy rozmowy na union.
- `src/lib/storage.ts`
  - zapisywać nowy model rozmowy,
  - dodać fallback odczytu starych danych.

Akceptacja:

- frontend umie wczytać stare sesje,
- nowe sesje zapisują pełniejszy model.

### Etap 2. Znormalizować `output[]`

Zmiany:

- `src/lib/chat-api.ts`
  - dodać parser wszystkich typów outputu,
  - nie redukować wszystkiego do `message`,
  - zwracać `items`.

Akceptacja:

- response zachowuje pełny `output`,
- nieznane typy nie znikają.

### Etap 3. Zmienić sposób dopisywania odpowiedzi agenta

Zmiany:

- `src/App.tsx`
  - po odpowiedzi backendu dopisywać `AgentResponse`,
  - zamiast `createMessage('assistant', response.message)`,
  - używać `items` z parsera.

Akceptacja:

- w feedzie pojawia się cały blok odpowiedzi agenta,
  - nie tylko jeden string.

### Etap 4. Dodać komponenty renderujące pełny kontekst itemów

Zmiany:

- dodać osobne komponenty dla `reasoning`, `tool_call`, `tool_output`,
- spiąć je z obecnym layoutem terminalowym.

Akceptacja:

- jeśli backend zwróci `reasoning`, UI go pokaże,
- jeśli backend zwróci `function_call_output`, UI go pokaże,
- `text` dalej renderuje się jako markdown.

## TODO: przygotowanie pod subagentów

Na ten etap nic z tego nie implementujemy, ale warto zostawić miejsce w modelu.

Jeśli później pojawią się child `Agents`, frontend nie powinien wymagać kolejnej przebudowy. Dlatego już teraz warto:

- trzymać odpowiedź jako blok przypisany do `Agent`, nie do abstrakcyjnego "assistant turn",
- dopuścić metadane:
  - `agentId`
  - `parentAgentId`
  - `depth`
  - opcjonalnie `agentName`
- nie zakładać, że wszystkie `Items` w `Session` należą do jednego agenta.

Minimalna zasada future-proof:

- `Session` może zawierać wiele `Agents`,
- każdy `Agent` może mieć własne `Items`,
- UI na razie może renderować wszystko liniowo,
- ale model danych musi pozwalać później dodać grouping albo indentację po `Agent` i `depth`.

### Etap 5. Dodać bezpieczne fallbacki

Zmiany:

- render `unknown`,
- defensywne parsowanie JSON-a,
- skracanie bardzo dużych payloadów,
- możliwość rozwinięcia szczegółów.

Akceptacja:

- frontend nie psuje się na nowym typie outputu,
- duże wyniki tooli nie rozwalają layoutu.

## Minimalna zależność od backendu

Żeby ten plan był faktycznie użyteczny dla pełnego zakresu, backend musi finalnie zwracać:

- `reasoning`,
- `function_call_output`.

Frontend można jednak wdrożyć już teraz, bo:

- pokaże `text`,
- pokaże `function_call`,
- będzie gotowy na pozostałe typy bez kolejnej przebudowy.

## Kryteria akceptacji

- frontend nie składa już całej odpowiedzi do jednego `message`,
- jedna tura asystenta potrafi pokazać wiele itemów w kolejności,
- `text` renderuje się przez markdown,
- `reasoning` renderuje się jako zwijany blok,
- `function_call` renderuje się jako karta z argumentami,
- `function_call_output` renderuje się jako karta wyniku,
- nieznane typy nie giną, tylko trafiają do fallbacku `unknown`.

## Najkrótsza rekomendacja

Najlepszy ruch na teraz to:

1. zostawić obecny wygląd czatu,
2. wymienić model danych z "assistant message" na "Agent + Items",
3. dodać renderer pełnego `output[]`,
4. nie przepinać całego feedu na CopilotKit runtime.

To jest najtańsza droga do "pełnego kontekstu" bez mieszania tematu ze streamingiem.
