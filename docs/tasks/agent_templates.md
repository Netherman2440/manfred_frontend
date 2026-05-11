# Agent Templates — frontend

## Cel

Pełen UI dla CRUD agentów: lista, podgląd, kreator i edycja. Dokument zastępuje sekcje 1–3 z poprzedniego `agents-column-and-tabs-ui.md` (data layer + agents column + agent detail tab) i je rozszerza o:
- Plus icon w lewej kolumnie → ekran kreatora agenta
- Ołówek przy profilu agenta w prawej kolumnie → ekran edycji
- Tools picker, model dropdown, color picker, system prompt

Tematy nie-agentowe (download attachmentów, threads tab, files tab placeholder) trafiły do `download_file.md` lub zostają w starym `agents-column-and-tabs-ui.md`.

Specyfikacja jest self-contained — nie wymaga zaglądania do backendu (kontrakty API są tu).

---

## Kontrakty API (referencja)

```
GET    /api/v1/agents
GET    /api/v1/agents/{name}
POST   /api/v1/agents                              { name, color, description, model, tools, system_prompt }
PUT    /api/v1/agents/{name}                       { name (== path), color, description, model, tools, system_prompt }
GET    /api/v1/agents/{name}/sessions
GET    /api/v1/tools                               { data: [{ name, description, type }] }
GET    /api/v1/models                              { data: [{ id, name, context_length, pricing_prompt_per_1k, pricing_completion_per_1k }] }
```

Schemat odpowiedzi `AgentDetail`:
```json
{
  "data": {
    "name": "manfred",
    "color": "#5EA1FF",
    "description": "Główny asystent...",
    "model": "openai/gpt-4o-mini",
    "system_prompt": "You are...",
    "tools": ["read_file", "write_file"]
  }
}
```

Błędy:
- `409 Conflict` przy POST z istniejącą nazwą → response `{"detail": "agent_already_exists"}`
- `422 Unprocessable Entity` → `{"detail": [{loc, msg, type}]}` dla walidacji name/color/tools
- `404 Not Found` przy PUT/GET nieistniejącego

---

## Decyzje UX

### Kreator otwiera się jako pełen ekran w głównym obszarze

Plus w lewej kolumnie i ołówek w prawej kolumnie **podmieniają główny obszar** (gdzie normalnie jest konwersacja) na ekran kreatora. Nie modal, nie overlay-fullscreen, nie nowy route Navigator-owy. Reguła: kreator działa w obrębie `ChatWorkspacePage` przez `workspaceModeProvider`.

Powody:
- Layout kolumn (sessions, agents, additional) zostaje widoczny → użytkownik nie traci kontekstu
- Wracamy do "ostatnio otwartej sesji" przez restore stanu w providerze (sessionId), nie przez Navigator.pop
- Łatwiejsza synchronizacja z prawą kolumną (preview agenta po lewej, edytor po prawej? Nie — edytor zajmuje całą kolumnę middle)

### Stan workspace mode

Wprowadzamy nowy enum:

```dart
enum WorkspaceMode {
  conversation,   // domyślne — pokazuje conversation_column z aktualną sesją
  agentEditor,    // pokazuje AgentEditorView w głównym obszarze
}
```

`workspaceModeProvider` (StateProvider) trzyma aktualny tryb. Razem z nim `agentEditorTargetProvider` trzyma cel edycji:

```dart
class AgentEditorTarget {
  const AgentEditorTarget.create() : agentName = null;
  const AgentEditorTarget.edit(this.agentName);
  final String? agentName;   // null = create mode
  bool get isCreate => agentName == null;
}
```

Save zamyka edytor: `workspaceModeProvider.notifier.state = WorkspaceMode.conversation`. Stan ostatnio otwartej sesji jest zachowany w `selectedSessionIdProvider` (już istnieje), więc po prostu wraca.

### Aktywny agent vs aktywna sesja

Klikany agent w lewej kolumnie → automatycznie otwiera ostatnią sesję dla tego agenta:

1. Tap na agent → wyzwala `_onAgentTap(agent)`
2. W handler: pobieramy ostatnią sesję dla `agent.name` z `GET /api/v1/agents/{name}/sessions`
3. Jeśli sesja istnieje → ustawiamy `selectedSessionIdProvider.state = lastSession.id` (przełącza konwersację)
4. Jeśli nie istnieje → proponujemy nową rozmowę z tym agentem (można opcjonalnie auto-create albo pokazać przycisk)

**Invariant**: `selectedAgentNameProvider` jest zawsze non-null — przy starcie aplikacji = kDefaultAgentName ("manfred"). Nigdy nie ma sytuacji "brak wybranego agenta".

**Implementacyjnie**: `AgentColumn._onAgentTap` staje się async:

```dart
Future<void> _onAgentTap(AgentSummary agent) async {
  ref.read(selectedAgentNameProvider.notifier).state = agent.name;
  
  try {
    final sessions = await ref.read(agentsRepositoryProvider).getAgentSessions(agent.name);
    if (sessions.isNotEmpty) {
      // Otwórz ostatnią (pierwszą na liście — sorted by date desc)
      ref.read(selectedSessionIdProvider.notifier).state = sessions.first.id;
    }
    // else: no sessions for this agent — user starts new conversation
  } catch (e) {
    // error handling
  }
}
```

**Repo method**: `AgentsRepository.getAgentSessions(String name)` → `GET /api/v1/agents/{name}/sessions`

**Wybór agenta przy nowej rozmowie**: `composer_controller` zawsze dostaje `rootAgentName = selectedAgentNameProvider` (nigdy null). Frontend i backend zawsze są zsynchronizowane na aktualnym agencie.

---

## 1. Warstwa danych

### Domain models (`lib/features/agents/domain/`)

**`agent_summary.dart`**:
```dart
class AgentSummary {
  const AgentSummary({
    required this.name,
    this.color,
    this.description,
  });
  final String name;
  final Color? color;
  final String? description;
}
```

**`agent_detail.dart`**:
```dart
class AgentDetail {
  const AgentDetail({
    required this.name,
    this.color,
    this.description,
    this.model,
    required this.systemPrompt,
    required this.tools,
  });
  // ...
  AgentDetail copyWith({...});
}
```

**`agent_input.dart`** (do POST/PUT):
```dart
class AgentInput {
  const AgentInput({
    required this.name,
    this.color,
    this.description,
    this.model,
    required this.tools,
    required this.systemPrompt,
  });
  final String name;
  final Color? color;
  final String? description;
  final String? model;
  final List<String> tools;
  final String systemPrompt;

  Map<String, dynamic> toJson();   // serializuje color → "#RRGGBB"
}
```

**`tool_summary.dart`**:
```dart
enum ToolKind { function, webSearch, mcp }

class ToolSummary {
  final String name;
  final String? description;
  final ToolKind kind;
}
```

**`model_summary.dart`**:
```dart
class ModelSummary {
  final String id;          // "openai/gpt-4o-mini"
  final String displayName; // "GPT-4o mini" (fallback do id)
  final int? contextLength;
  final double? pricingPromptPer1k;
  final double? pricingCompletionPer1k;
}
```

### DTO (`lib/features/agents/data/`)

**`agents_dto.dart`** — `AgentSummaryDto`, `AgentDetailDto`, `AgentInputDto` (`.toJson()`), response wrappers.

Parsowanie hex koloru → `Color`:
```dart
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return null;
  return Color(int.parse('FF$cleaned', radix: 16));
}

String? formatHexColor(Color? color) {
  if (color == null) return null;
  return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
```

**`tools_dto.dart`**, **`models_dto.dart`** analogicznie.

### Repository

**`agents_repository.dart`**:
```dart
abstract class AgentsRepository {
  Future<List<AgentSummary>> listAgents();
  Future<AgentDetail> getAgent(String name);
  Future<AgentDetail> createAgent(AgentInput input);
  Future<AgentDetail> updateAgent(String name, AgentInput input);
  Future<List<SessionListEntry>> getAgentSessions(String name);  // last opened first
  Future<void> deleteAgent(String name);  // throws AgentHasSessions (409)
}

class HttpAgentsRepository implements AgentsRepository {
  // GET    /agents
  // GET    /agents/{name}
  // POST   /agents (json)
  // PUT    /agents/{name} (json)
  // DELETE /agents/{name}
  // GET    /agents/{name}/sessions
}

final agentsRepositoryProvider = Provider<AgentsRepository>((ref) =>
    HttpAgentsRepository(apiClient: ref.watch(manfredApiClientProvider)));
```

**`tools_repository.dart`** — list tooli (cache w providerze, jednorazowy fetch).
**`models_repository.dart`** — list modeli (cache w providerze).

### `ManfredApiClient` — uzupełnienie

Dodać metody jeśli brak:
```dart
Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body);
Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body);
Future<void> deleteRequest(String path);
```

Jeśli już istnieją (sessions używają POST/PUT) — nie duplikuj.

### Providers (`lib/features/agents/application/`)

**`agents_list_provider.dart`**:
```dart
final agentsListProvider = AsyncNotifierProvider<AgentsListNotifier, List<AgentSummary>>(
  AgentsListNotifier.new,
);

class AgentsListNotifier extends AsyncNotifier<List<AgentSummary>> {
  @override
  Future<List<AgentSummary>> build() => ref.read(agentsRepositoryProvider).listAgents();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(agentsRepositoryProvider).listAgents());
  }
}
```

**`selected_agent_provider.dart`**:
```dart
// Config: default agent name (read from settings lub hardcoded "manfred")
const String kDefaultAgentName = "manfred";

final selectedAgentNameProvider = StateProvider<String>((ref) => kDefaultAgentName);

final selectedAgentDetailProvider = FutureProvider.autoDispose<AgentDetail>((ref) async {
  final name = ref.watch(selectedAgentNameProvider);
  return ref.watch(agentsRepositoryProvider).getAgent(name);
});
```

**Invariant**: `selectedAgentNameProvider` nigdy nie jest `null` — zawsze istnieje wybrany agent. Przy starcie aplikacji → default ("manfred").

**`tools_list_provider.dart`** — `FutureProvider<List<ToolSummary>>`, fetch raz, cache w providerze.

**`models_list_provider.dart`** — analogicznie. Cache nie wygasa w obrębie sesji aplikacji (backend ma 1h TTL — wystarczy).

**`agent_editor_provider.dart`**:
```dart
final workspaceModeProvider = StateProvider<WorkspaceMode>((ref) => WorkspaceMode.conversation);
final agentEditorTargetProvider = StateProvider<AgentEditorTarget?>((ref) => null);
```

---

## 2. Agents Column — refactor do real data

Plik: `lib/ui/screens/chat_workspace/columns/agent_column.dart`.

### Sygnatura

```dart
class AgentColumn extends ConsumerWidget {
  const AgentColumn({super.key, this.compact = false});
  final bool compact;
}
```

Czyta `agentsListProvider` + `selectedAgentNameProvider`.

### Stany

- `loading` → `_AgentColumnSkeleton` (3 placeholder kółka + plus button na dole)
- `error` → `_AgentColumnError` (retry button → `agentsListProvider.notifier.refresh()`)
- `data` → faktyczna lista

### Plus button

Na dole listy (lub na końcu Compact horizontal scroll) — `_AddAgentButton`:

```dart
class _AddAgentButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Nowy agent',
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          ref.read(agentEditorTargetProvider.notifier).state = const AgentEditorTarget.create();
          ref.read(workspaceModeProvider.notifier).state = WorkspaceMode.agentEditor;
        },
        child: const _PlusAvatar(),  // okrągły placeholder z ikoną +
      ),
    );
  }
}
```

`_PlusAvatar` — kółko ~44px z `Icons.add`, używa stylu `ManfredColors.panelAltBackground` + dashed border.

### Aktywny agent

Element listy (`_AgentRailItem`) ma stan `isActive = agent.name == selectedAgentName`. Visual: ring wokół avatara w `agent.color ?? ManfredColors.accentBlue`.

### Tap

Patrz sekcję "Aktywny agent vs aktywna sesja" — tap na agenta otwiera ostatnią sesję dla tego agenta.

### Avatar — image vs inicjały

`AgentAvatar` (`lib/ui/core/agent_avatar.dart`) musi wspierać oba przypadki:

```dart
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({
    super.key,
    this.imageUrl,
    this.label,           // 2 litery z name (fallback)
    this.accentColor,
    this.size = 44,
    this.isActive = false,
  });

  final String? imageUrl;
  final String? label;
  final Color? accentColor;
  final double size;
  final bool isActive;
}
```

Jeśli `imageUrl != null` → `Image.network(imageUrl, fit: BoxFit.cover)` w okrągłym Clip.
Jeśli `imageUrl == null` lub błąd ładowania → fallback do inicjałów + accentColor.

Inicjały: pierwsze 2 znaki name, uppercase. Dla `manfred` → `MA`. Dla wieloczłonowych (`my-agent`) → `MA`.

**Caching**: `Image.network` używa default Flutter image cache. Dla web — same. Wystarczy.

### Migracja z `AgentMock`

`AgentMock` zostaje w `lib/ui/mock/manfred_mock_data.dart` jako fallback dev (np. używany przez storybook). Główny `ChatWorkspacePage` nie czyta `ManfredMockData.agents` — zamiast tego `AgentColumn` jest Consumerem.

`ChatWorkspacePage` zmiana: usunąć przekazywanie `agents:` do `AgentColumn` (jeśli było).

---

## 3. Agent Editor — kreator i edytor

Główny komponent: `AgentEditorView`.

Plik: `lib/ui/screens/chat_workspace/agent_editor/agent_editor_view.dart` (NOWY).

### Layout

```
┌──────────────────────────────────────────────────────┐
│ [← Back]  Nowy agent / Edycja: {name}                │
├──────────────────────────────────────────────────────┤
│                                                      │
│   ┌─────────────────────────────────┬──────────┐   │
│   │ Agent Name        [__________]   │ [■ Click]    │ ← name na color, color picker obok
│   └─────────────────────────────────┴──────────┘   │
│                                                      │
│   Description         [_________________________]  │
│                                                      │
│   Model               [Dropdown ▼]                   │
│                                                      │
│   Tools                                              │
│   [☑ read_file]  [☐ write_file]  [☐ web_search]    │
│   [☐ delegate]   [☑ search_file] ...                │
│                                                      │
│   System prompt                                      │
│   ┌─────────────────────────────────────────────┐  │
│   │ multiline editor (mono font, ~12 rows)      │  │
│   └─────────────────────────────────────────────┘  │
│                                                      │
│                            [Cancel]  [Save]          │
└──────────────────────────────────────────────────────┘
```

**Color picker**: Row z background w aktualnym kolorze agenta (lub fallback neutral), tekst "Agent Name" wycentrowany, obok mały kwadracik (32x32) w tym kolorze — tap otwiera modal z paletką 8 kolorów.

### Form state

`AgentEditorView` to `ConsumerStatefulWidget`. Trzyma `TextEditingController`-y dla name/description/system_prompt + lokalny `_AgentEditorState`:

```dart
class _AgentEditorState {
  String name;
  Color? color;
  String description;
  String? model;
  Set<String> selectedTools;
  String systemPrompt;
}
```

### Initialization

W `initState()`:
1. `target = ref.read(agentEditorTargetProvider)`
2. Jeśli `target.isCreate` → `_state = _AgentEditorState.empty()`
3. Jeśli edit:
   - Watch `selectedAgentDetailProvider` (lub jednorazowy `getAgent(target.agentName)`)
   - Pre-fill controllerów + state
   - Loading state w międzyczasie

### Color picker

`_ColorPickerField`:
- Row z background w `_state.color ?? neutralColor`
- Tekst "Agent Name" wycentrowany na tym backgroundzie
- Obok kwadracik 32x32 w tym samym kolorze — tap otwiera modal z paletką
- Modal pokazuje 8 predefiniowanych kolorów:

```dart
const _kAgentPalette = <Color>[
  Color(0xFF5EA1FF), Color(0xFF76D39B), Color(0xFFF5C271),
  Color(0xFFF28A8A), Color(0xFFB68AF2), Color(0xFF6BD4DA),
  Color(0xFFE0A0F0), Color(0xFF9DA5B4),
];
```

- Tap na kolor w modalu → ustawia `_state.color` i zamyka modal
- Live preview: nazwa agenta natychmiast zmienia background

### Model dropdown

`_ModelDropdownField`:
- Czyta `modelsListProvider`
- `DropdownButtonFormField<String>` z search (alternatywnie `Autocomplete<ModelSummary>` jeśli lista długa — OpenRouter ma >100 modeli)
- Display: `model.displayName` + small subtitle z context_length i pricing
- Wybór ustawia `_state.model = modelSummary.id`
- Loading state: skeleton

### Tools picker

`_ToolsPickerField`:
- Czyta `toolsListProvider`
- Grupowane według `ToolKind`: function, web_search, mcp
- Każda pozycja: `Checkbox` + name + tooltip z description
- Wybór togguje członkostwo w `_state.selectedTools`

### System prompt field

`_SystemPromptField`:
- `TextField` multiline, `maxLines: null`, monospace font
- Min 8 wierszy, expand z zawartością
- Counter z licznikiem znaków (limit 20000 — backend wymusza)

### Save flow

```dart
Future<void> _onSave() async {
  if (!_validate()) return;
  setState(() => _saving = true);

  try {
    final input = AgentInput(
      name: _state.name,
      color: _state.color,
      description: _state.description.isEmpty ? null : _state.description,
      model: _state.model,
      tools: _state.selectedTools.toList()..sort(),
      systemPrompt: _state.systemPrompt,
    );

    final repo = ref.read(agentsRepositoryProvider);
    final detail = target.isCreate
        ? await repo.createAgent(input)
        : await repo.updateAgent(target.agentName!, input);

    // Refresh lists & selection
    await ref.read(agentsListProvider.notifier).refresh();
    ref.invalidate(selectedAgentDetailProvider);

    // Close editor → wróć do conversation mode
    ref.read(workspaceModeProvider.notifier).state = WorkspaceMode.conversation;
    ref.read(agentEditorTargetProvider.notifier).state = null;
  } on AgentAlreadyExists catch (_) {
    _showError('Agent o takiej nazwie już istnieje');
  } on AgentValidationError catch (e) {
    _showFieldErrors(e.fieldErrors);
  } catch (e) {
    _showError('Nie udało się zapisać agenta: $e');
  } finally {
    setState(() => _saving = false);
  }
}
```

`AgentAlreadyExists` i `AgentValidationError` to niestandardowe wyjątki z `HttpAgentsRepository` — repo mapuje 409/422 na nie.

### Walidacja klient-side

- `name`: regex `^[a-z][a-z0-9_-]{0,47}$`. Live walidacja w `TextField.validator`.
- `color`: nullable
- `description`: maxLength 500
- `system_prompt`: maxLength 20000
- `tools`: dowolny subset z `toolsListProvider` (live UI nie pozwala wpisać złych)

Live walidacja: name jest disabled w edit mode (nie zmienia się).

### Cancel flow

```dart
void _onCancel() async {
  if (_isDirty()) {
    final confirmed = await showDialog<bool>(...);
    if (!confirmed) return;
  }
  ref.read(workspaceModeProvider.notifier).state = WorkspaceMode.conversation;
  ref.read(agentEditorTargetProvider.notifier).state = null;
}
```

### Routing w `ChatWorkspacePage`

`ChatWorkspacePage` przy renderze środkowej kolumny:

```dart
final mode = ref.watch(workspaceModeProvider);
return switch (mode) {
  WorkspaceMode.conversation => const ConversationColumn(),
  WorkspaceMode.agentEditor => const AgentEditorView(),
};
```

Lewa i prawa kolumna nie zmieniają się — zostają widoczne i interaktywne.

---

## 4. Right panel — agent detail z ołówkiem

Tutaj uzupełnienie do tego, co poprzedni doc opisał jako "Tab 2 Agent". Rozszerzamy `AgentDetailView`.

Plik: `lib/ui/screens/chat_workspace/additional/agent_detail_view.dart`.

### Layout

```
┌────────────────────────────────────┐
│  [✎ Edit]                          │
│                                    │
│  Manfred                           │
│  openai/gpt-4o-mini                │
│                                    │
│  Główny asystent do pracy z kodem  │
│  (description)                     │
│                                    │
│  Tools                             │
│  [chip] [chip] [chip]              │
│                                    │
│  System prompt          [Show all] │
│  ┌──────────────────────────────┐ │
│  │ You are Manfred, a helpful... │ │
│  │ ... (200 chars truncated)     │ │
│  └──────────────────────────────┘ │
│                                    │
└────────────────────────────────────┘
```

**Nota**: Listy sesji dla agenta już są wyświetlane w kolumnie sesji (środkowa kolumna) — nie duplikujemy tutaj. Right panel pokazuje tylko template agenta.

### Komponenty

`_AgentDetailHeader`:
- Edit button — ikona ołówka:
  ```dart
  IconButton(
    icon: const Icon(Icons.edit_outlined),
    tooltip: 'Edytuj agenta',
    onPressed: () {
      ref.read(agentEditorTargetProvider.notifier).state =
          AgentEditorTarget.edit(detail.name);
      ref.read(workspaceModeProvider.notifier).state = WorkspaceMode.agentEditor;
    },
  ),
  ```
- Delete button (opcjonalnie, pokaż ikonę 🗑️ lub `Icons.delete_outline`):
  ```dart
  IconButton(
    icon: const Icon(Icons.delete_outline),
    tooltip: 'Usuń agenta',
    onPressed: () => _showDeleteConfirmation(context, detail.name, ref),
  )
  ```

`_showDeleteConfirmation` → pobiera sesje, pokazuje warning dialog:
```dart
Future<void> _showDeleteConfirmation(
  BuildContext context,
  String agentName,
  WidgetRef ref,
) async {
  // Pobierz sesje aby znać liczbę
  late List<SessionListEntry> sessions;
  try {
    sessions = await ref.read(agentsRepositoryProvider).getAgentSessions(agentName);
  } catch (e) {
    _showError('Błąd przy pobieraniu sesji: $e');
    return;
  }

  final sessionCount = sessions.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Usuń agenta'),
      content: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: 'Czy na pewno chcesz usunąć agenta "$agentName"?\n\n'),
            TextSpan(
              text: '⚠️ Usuniesz również $sessionCount sesję/sesji z tym agentem.',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Usuń agenta i sesje'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(agentsRepositoryProvider).deleteAgent(agentName);
    
    // Refresh lists
    await ref.read(agentsListProvider.notifier).refresh();
    
    // Switch do default agenta
    ref.read(selectedAgentNameProvider.notifier).state = kDefaultAgentName;
  } catch (e) {
    _showError('Błąd przy usuwaniu agenta: $e');
  }
}
```

`_AgentDetailBody`:
- Name (titleLarge)
- Model badge (chip)
- Description (bodyMedium)
- Tools chips (lista nazw — bez kategorii)
- System prompt collapsible (`_CollapsibleText` — pierwsze 200 znaków, "Show all" → expand)


---

## 5. Integracja z chat flow

### Wybór agenta przy submitcie

`composer_controller.dart` (już używa `rootAgentName`) — odczytujemy z `selectedAgentNameProvider`:

```dart
// W komponencie composera:
final selectedAgent = ref.watch(selectedAgentNameProvider);

ElevatedButton(
  onPressed: () => composerController.submit(rootAgentName: selectedAgent),
)
```

`selectedAgent` jest zawsze non-null (inicjalizowany do kDefaultAgentName przy starcie). Frontend zawsze wie jaki agent jest aktywny.

### Avatar agenta przy chat-itemach

`AgentMessageItem` (`lib/ui/screens/chat_workspace/conversation/items/agent_message_item.dart`):
- Aktualnie pokazuje placeholder/avatar z `AgentMock` lub `RootAgentSummary`
- Zmiana: jeśli message zawiera `agent_id` lub `agent_name`, czytamy z providera detail tego agenta i pokazujemy `AgentAvatar(...)` z inicjałami. Cache lokalny w providerze (już istnieje per-name).

Model wiadomości potrzebuje `agentName: String?`. Jeśli SessionItem już ma `agent_id` ale nie `agent_name`, pobieramy mapping z `SessionDetails.rootAgent.name` (dla root) lub w przyszłości z dedykowanego endpointa per-agent (sub-agenci). MVP: dla rootowych wiadomości używamy `details.rootAgent.name` → pobieramy `AgentDetail`.

W praktyce jeden Provider z lookupem `Map<String, AgentDetail>`:

```dart
final agentDetailByNameProvider = FutureProvider.family<AgentDetail?, String>((ref, name) async {
  return ref.watch(agentsRepositoryProvider).getAgent(name);
});
```

`AgentMessageItem` używa `ref.watch(agentDetailByNameProvider(message.agentName))` — Riverpod cachuje per-key.

---

## Pliki do stworzenia / zmiany

| Plik | Akcja |
|------|-------|
| `lib/features/agents/domain/agent_summary.dart` | NOWY |
| `lib/features/agents/domain/agent_detail.dart` | NOWY |
| `lib/features/agents/domain/agent_input.dart` | NOWY |
| `lib/features/agents/domain/agent_editor_target.dart` | NOWY |
| `lib/features/agents/domain/tool_summary.dart` | NOWY |
| `lib/features/agents/domain/model_summary.dart` | NOWY |
| `lib/features/agents/data/agents_dto.dart` | NOWY |
| `lib/features/agents/data/tools_dto.dart` | NOWY |
| `lib/features/agents/data/models_dto.dart` | NOWY |
| `lib/features/agents/data/agents_repository.dart` | NOWY |
| `lib/features/agents/data/tools_repository.dart` | NOWY |
| `lib/features/agents/data/models_repository.dart` | NOWY |
| `lib/features/agents/application/agents_list_provider.dart` | NOWY |
| `lib/features/agents/application/selected_agent_provider.dart` | NOWY |
| `lib/features/agents/application/tools_list_provider.dart` | NOWY |
| `lib/features/agents/application/models_list_provider.dart` | NOWY |
| `lib/features/agents/application/agent_editor_provider.dart` | NOWY |
| `lib/ui/screens/chat_workspace/columns/agent_column.dart` | Refaktor: ConsumerWidget, real data, plus button |
| `lib/ui/screens/chat_workspace/additional/agent_detail_view.dart` | NOWY |
| `lib/ui/screens/chat_workspace/agent_editor/agent_editor_view.dart` | NOWY |
| `lib/ui/screens/chat_workspace/agent_editor/color_picker_field.dart` | NOWY |
| `lib/ui/screens/chat_workspace/agent_editor/tools_picker_field.dart` | NOWY |
| `lib/ui/screens/chat_workspace/agent_editor/model_dropdown_field.dart` | NOWY |
| `lib/ui/screens/chat_workspace/agent_editor/system_prompt_field.dart` | NOWY |
| `lib/ui/screens/chat_workspace/chat_workspace_page.dart` | Switch między ConversationColumn ↔ AgentEditorView |
| `lib/core/api/manfred_api_client.dart` | PUT, DELETE jeśli brak |

---

## Kolejność implementacji

1. **Data layer** — domain models, DTO, repository, providers (lista agentów, detail, tools, models, agent sessions)
2. **AgentColumn refactor** — real data + plus button + tap handler (otwiera ostatnią sesję agenta)
3. **AgentEditorView** — szkielet + wszystkie field components
4. **Save flow** — POST/PUT, walidacja, error handling, refresh
5. **AgentDetailView** w prawej kolumnie — z ikoną ołówka łączy się z editor providerem
6. **Avatar agenta w chat itemach**

---

---

## Out of scope (V1)

- Rename agenta — **V2 feature** (atomic rename folder + files)
- Custom HSV/RGB color picker — wystarczy paletka 8 kolorów
- Drag-drop reorder agentów w lewej kolumnie
- Search/filter listy agentów (mało ich, niepotrzebne)
- Podgląd zmian system prompt jako diff przy edycji
- Sub-agenci (delegate) — templatka wybiera sub-agentów przez tool `delegate`, ale UI nie modeluje tej relacji
