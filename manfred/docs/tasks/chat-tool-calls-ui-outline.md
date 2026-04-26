# Task Spec: Chat Tool Calls UI

## Cel

Uspójnić transcript workspace w `manfred_frontend`, tak aby tool calle wspierały rozmowę zamiast ją technicznie zaśmiecać.

Najważniejsze cele frontendowe:
- poprawić collapsed i expanded view zwykłych sync tool calli,
- umożliwić kopiowanie treści z transcriptu,
- potraktować `delegate` jako komunikat agentowy,
- potraktować `ask_user` / `waiting_for` jako ping do użytkownika,
- przygotować UI pod subwątki delegowanych agentów.

Dokument nadrzędny:
- `../../../docs/chat-tool-calls-ui-outline.md`

## Kontekst lokalny dla repo

Obecny frontend ma już podstawy do renderowania transcriptu:
- itemy domenowe w `lib/features/sessions/domain/session_item.dart`
- mapowanie transcriptu w `lib/features/sessions/presentation/workspace_view_mapper.dart`
- widget technicznej karty tool calla w `lib/ui/screens/chat_workspace/conversation/items/tool_call_item.dart`
- istniejące widgety agentowe:
  - `agent_ping_item.dart`
  - `agent_thread_item.dart`

Stan obecny:
- zwykły tool call jest pokazywany jako techniczna karta,
- po rozwinięciu argumenty są de facto pokazywane drugi raz,
- transcript jest zbyt mało selektowalny do wygodnego kopiowania,
- `delegate` nie ma semantyki konwersacyjnej,
- nie ma jeszcze czytelnego modelu subwątków dla delegacji.

## Dane wejściowe i kontrakt z backendu

Frontend bazuje na obecnym modelu danych:
- `function_call`
- `function_call_output`
- `waiting_for`

Istotne przypadki:

### Zwykły sync tool call

Wejście:
- `function_call` z `arguments`
- opcjonalnie sparowany `function_call_output`

Oczekiwanie UI:
- collapsed preview ma wyglądać jak mała code-card,
- expanded view ma pokazywać argumenty i output bez wrażenia zdublowania tej samej treści.

### `delegate`

Wejście:
- `function_call` z `name = delegate`
- `arguments.agent_name`
- `arguments.task`

Oczekiwanie UI:
- render jako zwykły agent item z treścią `@{agent_name} {task}`,
- bez technicznej ramki tool calla,
- ma to wyglądać jak root agent pingujący subagenta.

### `ask_user` i `waiting_for`

Wejście:
- `function_call` / `function_call_output` związane z `ask_user`
- `waiting_for` z `type = agent`, `name = delegate`, `description`, `agent_id`

Oczekiwanie UI:
- przygotować reprezentację pingu do użytkownika w stylu `@{user_name} {description}`,
- nie implementować jeszcze pełnej zmiany wysyłki na `deliver`,
- jawnie zaznaczyć, że pełny UX wymaga osobnego taska backend+frontend.

## Zakres zmian w kodzie

Preferowane obszary zmian:
- `lib/features/sessions/domain/session_item.dart`
- `lib/features/sessions/presentation/workspace_view_mapper.dart`
- `lib/ui/screens/chat_workspace/conversation/items/tool_call_item.dart`
- `lib/ui/screens/chat_workspace/conversation/items/agent_ping_item.dart`
- `lib/ui/screens/chat_workspace/conversation/items/agent_thread_item.dart`
- `lib/ui/mock/manfred_mock_data.dart`
- testy widgetów i mapperów pod transcript

Możliwe zmiany strukturalne:
- dodanie frontendowych typów prezentacyjnych dla specjalnych tool calli,
- rozdzielenie „raw transcript item” od „conversation entry used by UI”,
- dopięcie selected state dla subwątku i powiązania z additional column.

## In-scope

- redesign collapsed preview dla sync tool calli,
- usunięcie wizualnej duplikacji argumentów,
- selekcja i kopiowanie tekstu,
- specjalny renderer dla `delegate`,
- specjalny renderer dla agentowego pingu do użytkownika,
- model UI dla subwątku delegacji,
- przygotowanie additional column do wyświetlania wewnętrznych itemów delegacji.

## Out-of-scope

- backendowy routing kolejnej wiadomości do `deliver`,
- zmiana kontraktu `chat/completions`,
- pełna semantyka zarządzania otwartym `waiting_for`,
- streaming,
- zmiana kolejności zapisu itemów po stronie backendu.

## Oczekiwane zachowanie

### 1. Zwykłe tool calle

- collapsed state pokazuje nazwę toola i krótkie code-style preview argumentów,
- expanded state pokazuje pełne argumenty i output,
- preview nie sprawia wrażenia, że użytkownik czyta te same argumenty dwa razy.

### 2. Wiadomości i transcript

- użytkownik może zaznaczyć i skopiować:
  - treść wiadomości użytkownika,
  - treść odpowiedzi asystenta,
  - preview i expanded content tool calli.

### 3. `delegate` jako komunikat

- `delegate` ma wyglądać jak agentowy ping:
  - autor: root agent,
  - treść: `@research task`
- bez technicznej obudowy typowej dla `calculator` albo innych zwykłych tooli.

### 4. `waiting_for` jako ping do użytkownika

- jeśli transcript / stan sesji wskazuje, że delegowany agent czeka na input usera, UI ma mieć sposób pokazania tego jako pingu do użytkownika,
- ten element ma być spójny wizualnie z agentowym pingiem, a nie z kartą debugową.

### 5. Subwątek delegacji

- delegacja ma tworzyć reprezentację „wątku”,
- kliknięcie w wątek ma otwierać jego zawartość w additional column,
- additional column pokazuje itemy należące do delegowanego przebiegu aż do jego aktualnego punktu zatrzymania albo odpowiedzi.

Na tym etapie spec nie wymaga jeszcze finalnej interakcyjnej implementacji wszystkich stanów; ważne jest ustalenie modelu UI i fallbacków.

## Acceptance Criteria

- collapsed tool call wygląda jak spójna code-card,
- expanded tool call nie dubluje argumentów w mylący sposób,
- tekst transcriptu jest selektowalny,
- `delegate` renderuje się jako agentowy ping,
- UI posiada osobny model prezentacyjny dla komunikatów delegacji i pingu do użytkownika,
- additional column ma zdefiniowany sposób pokazywania subwątku,
- kod posiada bezpieczny fallback do standardowego renderera, jeśli nie da się rozpoznać specjalnego przypadku.

## Test Plan

- testy jednostkowe:
  - mapowanie `SessionItem -> ConversationEntryMock` lub nowy model prezentacyjny,
  - rozpoznawanie specjalnych przypadków `delegate` i `ask_user`.
- testy widgetów:
  - collapsed sync tool call,
  - expanded sync tool call,
  - delegate ping,
  - user ping,
  - selectable transcript content.
- test manualny:
  - transcript zwykłego `calculator`,
  - transcript `delegate -> ask_user`,
  - otwarcie subwątku w additional column,
  - kopiowanie treści odpowiedzi i argumentów.

## Otwarte kwestie i follow-up

- Osobny task backend+frontend:
  - jeśli sesja ma aktywne `waiting_for`, następna wiadomość użytkownika powinna trafić do `deliver`, a nie do `chat/completions`.
- Możliwe przyszłe doprecyzowanie:
  - czy subwątek opiera się wyłącznie o `agent_id`,
  - czy potrzebny będzie jawny model thread group po stronie backendu.

Ten follow-up jest ważny, ale nie blokuje pierwszej iteracji UI.

## Handoff: manfred_frontend

Done:
- Zdefiniowano frontendowy zakres dla prezentacji tool calli, delegacji i przygotowania pod subwątki.

Contract:
- `delegate` i agentowe `waiting_for` są traktowane jako elementy rozmowy.
- Bieżący task nie zmienia backendowego kontraktu ani mechaniki `deliver`.

Next role:
- `integrator`

Risks:
- Obecny transcript może nie zawsze wystarczyć do idealnego odtworzenia subwątku bez późniejszego wsparcia backendowego.
- Łatwo przesunąć zakres z UI w stronę pełnej zmiany flow rozmowy, co nie jest celem tej iteracji.
