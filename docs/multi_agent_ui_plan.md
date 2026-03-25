# Plan wdrożenia UI dla tooli, reasoning i subagentów

## Cel

Dostosować `manfred_frontend` tak, aby jedna tura rozmowy mogła pokazać:

- `tool call` razem z odpowiadającym mu `tool answer`,
- `reasoning` jako jawny element timeline'u,
- sekcje agentów i subagentów,
- zagnieżdżenia subagent -> tool -> subagent,
- informację, który agent odpowiada i który agent jest aktualnie aktywny.

To nie jest kosmetyczna zmiana widoku. Obecny frontend umie wyrenderować pojedynczą, płaską listę itemów agenta, ale nie ma modelu drzewa wykonania.

## Stan obecny

### Frontend

- `src/App.tsx` renderuje feed jako płaskie `entries[]`.
- `src/components/AgentResponseBlock.tsx` renderuje jedną odpowiedź agenta z płaskim `items[]`.
- `src/components/ToolCallCard.tsx` i `src/components/ToolOutputCard.tsx` pokazują call i output oddzielnie, bez jawnego parowania.
- `src/types/chat.ts` ma `agentId`, `parentAgentId` i `depth`, ale tylko na poziomie całej odpowiedzi, nie na poziomie zagnieżdżonego drzewa agentów.
- `src/lib/storage.ts` zapisuje aktualny płaski model i nie przechowuje relacji agent -> child agent albo tool call -> tool result.

Wniosek: obecny frontend jest gotowy na "trace list", ale nie na "agent execution tree".

### Backend

`manfred` daje dziś częściowy fundament, ale nie pełny kontrakt dla takiego UI:

- `POST /api/v1/chat/completions` zwraca `sessionId`, `agentId`, `status`, `output[]`, `waitingFor[]`, `attachments[]`.
- `GET /api/v1/chat/agents/{agent_id}` zwraca `parentId`, `sourceCallId`, `depth`, `status`, `waitingFor`, `result`.
- runtime wspiera delegację do subagentów i ma relacje parent-child.

Braki względem docelowego UI:

- odpowiedź `chat/completions` nie zawiera pełnego drzewa agentów dla tury,
- nie ma `agentName` / `displayName`,
- `output[]` nie niesie informacji, który item należy do którego subagenta,
- frontend nie ma jednego snapshotu "całej orkiestracji" po zakończeniu tury.

Wniosek: pełne UI subagentów wymaga małego rozszerzenia kontraktu backendu. Sam frontend nie odtworzy wiarygodnie drzewa tylko z obecnego `output[]`.

## Założenie projektowe

Docelowy widok powinien opierać się nie na pojedynczym `message`, tylko na drzewie wykonania jednej tury:

1. `Turn`
2. `Agent section`
3. `Trace items`
4. opcjonalne `child agent sections`

Najważniejsza decyzja: nie próbować modelować subagentów jako zwykłych itemów tekstowych. Subagent musi być osobną sekcją UI z własnym nagłówkiem, statusem, itemami i dziećmi.

## Docelowy model danych w frontendzie

Rekomenduję rozdzielenie dwóch warstw:

### 1. Snapshot API

To jest surowa odpowiedź z backendu po jednej turze.

Minimalny kontrakt potrzebny pod nowe UI:

```ts
interface AgentTraceSnapshot {
  id: string
  name: string
  parentId?: string
  sourceCallId?: string
  depth: number
  status: 'pending' | 'running' | 'waiting' | 'completed' | 'failed' | 'cancelled'
  waitingFor?: WaitingFor[]
  items: RawAgentTraceItem[]
  children: AgentTraceSnapshot[]
}

interface ChatTurnTraceResponse {
  sessionId: string
  rootAgentId: string
  activeAgentId?: string
  turnStatus: 'completed' | 'waiting' | 'failed'
  agents: AgentTraceSnapshot[]
}
```

Najważniejsze pola obowiązkowe dla UX:

- `name`: żeby było widać, z którym agentem pracujemy,
- `parentId` i `sourceCallId`: żeby powiązać subagenta z delegującym tool callem,
- `activeAgentId`: żeby wskazać aktualnie pracującego agenta,
- `children` albo równoważna relacja parent-child.

### 2. View model

Frontend nie powinien renderować bezpośrednio surowego API. Potrzebny jest parser do modelu widoku:

```ts
interface AgentTreeNode {
  agentId: string
  agentName: string
  status: AgentStatus
  depth: number
  sourceCallId?: string
  toolGroups: ToolTraceGroup[]
  timeline: AgentTimelineItem[]
  children: AgentTreeNode[]
}

interface ToolTraceGroup {
  callId: string
  toolName: string
  callItem: FunctionCallAgentItem
  resultItem?: FunctionCallOutputAgentItem
  childAgents: AgentTreeNode[]
}
```

Kluczowe zasady:

- parowanie `tool call` i `tool result` odbywa się po `callId`,
- subagent delegowany z toola wpina się do grupy tego toola przez `sourceCallId`,
- finalny render opiera się na drzewie, nie na płaskiej tablicy.

## Docelowy układ UI

### 1. Feed rozmowy

Na poziomie feedu zostają:

- wiadomości usera,
- odpowiedzi systemu/agenta jako osobne "turn blocks".

Jedna odpowiedź agenta nie jest już pojedynczym markdown bubble, tylko kontenerem dla drzewa wykonania.

### 2. Turn block

Każda tura asystenta powinna mieć:

- nagłówek z `root agent`,
- badge statusu tury: `completed`, `waiting`, `failed`,
- informację `active agent`,
- przycisk expand/collapse całego trace.

To ograniczy chaos przy długich przebiegach z wieloma toolami.

### 3. Agent section

Każdy agent i subagent dostaje własną sekcję:

- nazwa agenta,
- `agentId` w drugiej linii lub tooltipie,
- status,
- depth,
- informacja "delegated from `<tool>`", jeśli ma `sourceCallId`,
- własny timeline itemów.

Sekcja powinna być renderowana rekurencyjnie, żeby obsłużyć subagentów dowolnej głębokości.

### 4. Timeline itemy

W obrębie sekcji agenta:

- `text` jako finalna wypowiedź lub krok roboczy,
- `reasoning` jako zwijana warstwa techniczna,
- `tool call + tool answer` jako jedna grupa widoku,
- `unknown` jako fallback developerski.

Najważniejsza zmiana UX: `tool call` i `tool answer` nie powinny już być osobnymi, luźnymi kartami. Powinny być jedną grupą "narzędzie", gdzie najpierw widać input, potem output, potem ewentualne child agenty uruchomione przez delegację.

### 5. Aktywny agent

Docelowo aktywny agent ma być widoczny w dwóch miejscach:

- globalnie w nagłówku turna: `active agent: planner`,
- lokalnie jako podświetlenie odpowiedniej sekcji agenta.

Jeśli status tury to `waiting`, nagłówek sekcji powinien też pokazywać `waitingFor`.

## Niezbędne zmiany kontraktu backendu

To jest warunek pełnego wdrożenia.

### Minimalny zakres

Rozszerzyć odpowiedź jednej tury o:

- `rootAgentId`,
- `activeAgentId`,
- listę agentów z `id`, `name`, `parentId`, `sourceCallId`, `depth`, `status`,
- itemy przypisane do konkretnego agenta,
- zachowanie kolejności itemów w obrębie agenta.

### Minimalny fallback, jeśli backend ma iść etapami

Jeżeli nie chcesz od razu budować pełnego `agents[]`, można wejść etapem pośrednim:

- zostawić obecne `output[]`,
- dodać osobne `agentTree[]` bez pełnego timeline'u,
- dodać `agentName` i `activeAgentId`,
- dodać endpoint agregujący stan wszystkich agentów w sesji lub turze.

Ale to jest wariant przejściowy. Finalnie frontend i tak powinien dostać jeden snapshot, bo inaczej złożenie spójnego widoku po wielu requestach będzie kruche.

## Plan wdrożenia

### Etap 1. Ustalić kontrakt danych dla trace'u agentów

Cel:

- ustalić jeden kanoniczny payload dla odpowiedzi tury.

Zakres:

- dopisać do backendu `agentName` / `displayName`,
- dopisać `rootAgentId`, `activeAgentId`,
- ustalić, czy backend zwraca drzewo `children[]`, czy płaską listę agentów z `parentId`,
- przypisać itemy do konkretnego agenta.

Efekt:

- frontend dostaje komplet danych potrzebnych do renderu bez heurystyk.

### Etap 2. Wydzielić w frontendzie model trace'u

Cel:

- oddzielić obecny prosty model wiadomości od modelu wykonania agentów.

Zakres:

- rozszerzyć `src/types/chat.ts` o:
  - `AgentTraceEntry`,
  - `AgentTreeNode`,
  - `AgentTimelineItem`,
  - `ToolTraceGroup`,
- utrzymać `ChatMessage` dla usera bez zmian,
- zmienić `ChatEntry` na model, który wspiera turn trace.

Efekt:

- frontend przestaje traktować odpowiedź agenta jako płaskie `items[]`.

### Etap 3. Zbudować normalizator API -> tree view model

Cel:

- zebrać logikę grupowania w jednym miejscu, nie w komponentach.

Zakres:

- przenieść parsowanie z `src/lib/chat-api.ts` do warstwy normalizacji trace'u,
- dodać:
  - mapowanie itemów do agentów,
  - parowanie `tool call` z `tool result`,
  - przypinanie child agentów po `sourceCallId`,
  - oznaczanie aktywnego agenta,
  - fallback `unknown`.

Rekomendacja:

- dodać osobny plik typu `src/lib/agent-trace.ts`.

Efekt:

- komponenty dostają gotowe, spójne drzewo do renderu.

### Etap 4. Przebudować render odpowiedzi agenta

Cel:

- zastąpić obecny `AgentResponseBlock` renderem rekurencyjnym.

Zakres:

- `AgentResponseBlock` zamienić w kontener turna,
- dodać komponenty:
  - `AgentTurnBlock`,
  - `AgentSection`,
  - `ToolTraceGroupCard`,
  - `SubagentList`,
  - `AgentStatusBadge`,
- zostawić `ReasoningBlock` i `StructuredDataBlock` jako elementy niższego poziomu.

Efekt:

- UI pokazuje hierarchię agentów zamiast jednej płaskiej kolumny kart.

### Etap 5. Dodać stany interakcji i czytelność przy dużym trace

Cel:

- utrzymać czytelność przy długich odpowiedziach.

Zakres:

- collapse dla:
  - całego turna,
  - sekcji subagenta,
  - reasoning,
  - szczegółów JSON tooli,
- sticky albo mocno widoczny badge aktywnego agenta,
- wyróżnienie błędów tooli i agentów,
- limit wysokości dla dużych wyników i scroll wewnątrz kart technicznych.

Efekt:

- trace jest używalny także przy głębokim zagnieżdżeniu.

### Etap 6. Zaktualizować persistence

Cel:

- po refreshu zachować nowy model odpowiedzi.

Zakres:

- rozszerzyć `src/lib/storage.ts` o serializację drzewa agentów,
- przygotować migrację z obecnego płaskiego `agent_response`,
- zachować kompatybilność wstecz dla starych zapisów.

Efekt:

- frontend nie traci struktury agent/subagent po odświeżeniu.

### Etap 7. Testy i scenariusze akceptacyjne

Cel:

- zabezpieczyć parser i rekurencyjny render.

Zakres testów:

- 1 agent, 1 tekst,
- 1 agent, wiele tooli,
- `tool call` bez `tool result`,
- `tool result` z błędem,
- agent z jednym child agentem,
- agent z child agentem, który ma własne toole,
- agent z child agentem, który ma własnego child agenta,
- nieznany item w payloadzie,
- restore ze storage.

## Rekomendowana kolejność wdrożenia

Najbardziej pragmatyczna kolejność:

1. kontrakt backendu,
2. model i normalizacja frontendowa,
3. płaski render z grupowaniem `tool call -> tool result`,
4. render drzewa subagentów,
5. aktywny agent i polish UX,
6. storage i testy.

To pozwala szybko dowieźć wartość etapami:

- najpierw czytelne toole,
- potem subagenty,
- na końcu pełna trwałość i dopracowanie UX.

## Definition of Done

Aktualizacja może zostać uznana za wdrożoną, gdy:

- odpowiedź jednej tury renderuje `reasoning`, `tool call`, `tool answer` i `text`,
- `tool call` i `tool answer` są powiązane w jednym bloku po `callId`,
- subagenty są renderowane jako zagnieżdżone sekcje, nie jako płaskie itemy,
- dla każdej sekcji widać nazwę agenta,
- UI wskazuje aktywnego agenta dla tury `waiting` lub `running`,
- struktura zachowuje się poprawnie po odświeżeniu strony,
- fallback `unknown` nie gubi nowych typów danych.

## Decyzje, których nie warto odkładać

Są trzy decyzje, które warto zamknąć od razu, bo wpływają na całą implementację:

- czy backend zwraca drzewo agentów, czy listę agentów z relacją `parentId`,
- skąd bierze się `agentName`,
- czy `activeAgentId` jest częścią odpowiedzi tury, czy trzeba go dopytywać osobnym endpointem.

Jeśli te trzy rzeczy pozostaną niejawne, frontend skończy z heurystykami i szybciej się rozsypie przy kolejnych zmianach orkiestracji.
