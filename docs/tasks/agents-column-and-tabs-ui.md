# Agents Column, Tabbed Right Panel & Attachments UI

## Cel

Trzy powiązane kawałki UI:

1. **Agents column** — zastąpić mock-data rzeczywistymi agentami z backendu
2. **Right panel (AdditionalColumn) → tabbed** — przebudowa prawej kolumny na zakładki: wątek subagenta / szczegóły agenta / (placeholder file system)
3. **Attachment download** — gdy AI zwróci attachment w odpowiedzi, użytkownik może go kliknąć i pobrać

Specyfikacja jest self-contained — nie wymaga zaglądania do repo backendu.

---

## Kontekst lokalny

### Struktura features

```
lib/
  core/api/
    manfred_api_client.dart     ← HttpClient, getJson/postJson/getBytes
  features/
    chat/                       ← composer, streaming, mutation
    sessions/                   ← SessionListEntry, SessionDetails, providers
    user/                       ← UserContextProvider
  ui/
    screens/chat_workspace/
      columns/
        agent_column.dart       ← używa AgentMock, do zamiany na real data
        additional_column.dart  ← prawa kolumna, do refaktoru na tabbed
        sessions_column.dart
        conversation_column.dart
      layout/
        desktop_workspace_layout.dart
      chat_workspace_page.dart
    mock/
      manfred_mock_data.dart    ← ManfredMockData, AgentMock — zostaje jako fallback dev
```

### Istniejące wzorce

- **Repository** — abstrakcyjna klasa + `Http*` implementacja + `Provider<Repository>` (wzorzec z `sessions_repository.dart`)
- **State** — Riverpod `AsyncNotifierProvider` lub `FutureProvider` (wzorzec z `sessions_list_provider.dart`)
- **DTO** — `*Dto` z `fromJson` i `.toDomain()` (wzorzec z `sessions_dto.dart`)

### API backendu (kontrakty do implementacji)

```
GET /api/v1/agents
Response:
{
  "data": [
    { "name": "manfred", "color": "#5EA1FF", "description": "Główny asystent..." },
    ...
  ]
}

GET /api/v1/agents/{name}
Response:
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

GET /api/v1/agents/{name}/sessions
Response:
{
  "data": [ <SessionListEntry identyczny z /users/{userId}/sessions> ]
}

GET /api/v1/sessions/{session_id}/files/download?path=<virtual_path>
Response: binary file (Content-Disposition: attachment)
```

### Aktualny stan prawej kolumny

`AdditionalColumn` ma dwa stany:
- `_ArtifactsView` — pokazuje mock highlights/resources gdy nie ma selectedThread
- `_ThreadView` — pokazuje transcript subagenta gdy `selectedThreadId != null`

Przełączanie odbywa się przez `selectedThreadId` przekazywany z `ChatWorkspacePage`.

### Attachment w sesji

`SessionDetails` zawiera `SessionItem`-y. `AgentConversationEntry` obecnie renderuje tylko tekst. Backend może zwrócić attachment w odpowiedzi agenta — format do obsługi opisany poniżej.

---

## Scope

**In-scope:**
- Nowa warstwa danych: `AgentSummary`, `AgentDetail` domain models + DTO + repository
- `AgentSummary` provider (lista agentów)
- `AgentDetail` provider (szczegóły klikniętego agenta)
- Agents column: zasilana z providera zamiast mock
- Prawa kolumna: tabbed (Tab 1 wątek, Tab 2 agent detail, Tab 3 placeholder)
- Attachment chip w wiadomości agenta + download call
- `AttachmentDownloadService` (jeden GET, zwraca bajty lub otwiera URL)

**Out-of-scope:**
- File system browser (Tab 3 to tylko placeholder)
- Tworzenie/edycja agentów
- Push/real-time update listy agentów
- Podgląd plików in-app (PDF viewer, image viewer)
- Sesje bez wybranego agenta (filtrowanie po agencie jest opcjonalne w V1 — można zostawić obecne zachowanie)

---

## 1. Warstwa danych — Agents

### Domain models

**`lib/features/agents/domain/agent_summary.dart`** — NOWY plik:
```dart
class AgentSummary {
  const AgentSummary({required this.name, this.color, this.description});
  final String name;
  final Color? color;         // parsujemy hex string z API
  final String? description;
}
```

**`lib/features/agents/domain/agent_detail.dart`** — NOWY plik:
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
  final String name;
  final Color? color;
  final String? description;
  final String? model;
  final String systemPrompt;
  final List<String> tools;
}
```

### DTO

**`lib/features/agents/data/agents_dto.dart`** — NOWY plik:
```dart
class AgentsListResponseDto {
  factory AgentsListResponseDto.fromJson(Map<String, dynamic> json) { ... }
  final List<AgentSummaryDto> data;
}

class AgentSummaryDto {
  factory AgentSummaryDto.fromJson(Map<String, dynamic> json) { ... }
  AgentSummary toDomain() { ... }  // parsuje color hex → Color
  final String name;
  final String? color;
  final String? description;
}

class AgentDetailResponseDto {
  factory AgentDetailResponseDto.fromJson(Map<String, dynamic> json) { ... }
  AgentDetail toDomain() { ... }
  // pola: name, color, description, model, system_prompt, tools
}
```

Parsowanie hex koloru: `Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16))`.

### Repository

**`lib/features/agents/data/agents_repository.dart`** — NOWY plik:
```dart
abstract class AgentsRepository {
  Future<List<AgentSummary>> listAgents();
  Future<AgentDetail> getAgent(String name);
}

class HttpAgentsRepository implements AgentsRepository {
  @override
  Future<List<AgentSummary>> listAgents() async {
    final payload = await _apiClient.getJson('/agents');
    return AgentsListResponseDto.fromJson(payload).data
        .map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<AgentDetail> getAgent(String name) async {
    final payload = await _apiClient.getJson('/agents/$name');
    return AgentDetailResponseDto.fromJson(payload).toDomain();
  }
}

final agentsRepositoryProvider = Provider<AgentsRepository>((ref) {
  return HttpAgentsRepository(apiClient: ref.watch(manfredApiClientProvider));
});
```

### Providers

**`lib/features/agents/application/agents_list_provider.dart`** — NOWY:
```dart
final agentsListProvider = AsyncNotifierProvider<AgentsListNotifier, List<AgentSummary>>(
  AgentsListNotifier.new,
);

class AgentsListNotifier extends AsyncNotifier<List<AgentSummary>> {
  @override
  Future<List<AgentSummary>> build() =>
      ref.read(agentsRepositoryProvider).listAgents();
}
```

**`lib/features/agents/application/selected_agent_provider.dart`** — NOWY:
```dart
// Prosty StateProvider — który agent jest aktualnie wybrany (name)
final selectedAgentNameProvider = StateProvider<String?>((ref) => null);

// Detail klikniętego agenta (lazy load po kliknięciu)
final selectedAgentDetailProvider = FutureProvider<AgentDetail?>((ref) async {
  final name = ref.watch(selectedAgentNameProvider);
  if (name == null) return null;
  return ref.read(agentsRepositoryProvider).getAgent(name);
});
```

**`lib/features/sessions/application/sessions_list_provider.dart`** — MODYFIKACJA:
Opcjonalne filtrowanie po agencie. Jeśli `selectedAgentName != null`, fetch z `/agents/{name}/sessions` zamiast `/users/{userId}/sessions`:
```dart
// Jeśli selectedAgentName != null:
//   GET /agents/{name}/sessions
// Else:
//   GET /users/{userId}/sessions  (obecne zachowanie)
```

---

## 2. Agents Column — real data

### Zmiany w `agent_column.dart`

Zamienić `List<AgentMock>` na `List<AgentSummary>`. Komponent staje się Consumerem (lub przyjmuje dane z zewnątrz po zmapowaniu).

**Nowa sygnatura:**
```dart
class AgentColumn extends ConsumerWidget {
  const AgentColumn({super.key, this.compact = false});
  // pobiera agentów z agentsListProvider
}
```

**Obsługa stanu ładowania:**
```dart
ref.watch(agentsListProvider).when(
  loading: () => _AgentColumnSkeleton(),
  error: (e, _) => _AgentColumnError(),
  data: (agents) => compact
    ? _CompactAgentColumn(agents: agents, onTap: _onAgentTap)
    : _DesktopAgentColumn(agents: agents, onTap: _onAgentTap),
);
```

**On tap:**
```dart
void _onAgentTap(String agentName) {
  ref.read(selectedAgentNameProvider.notifier).state = agentName;
}
```

**Aktywny agent** — podświetlamy ten, którego `name == selectedAgentName`.

**`AgentAvatar`** — już przyjmuje `label` (2 litery) i `accentColor`. Generujemy label z name: `name.substring(0, 2).toUpperCase()` jeśli brak dedykowanego pola.

---

## 3. Right panel — tabbed

### Nowe enum + klasy stanu

**`lib/features/agents/domain/right_panel_tab.dart`** — NOWY:
```dart
enum RightPanelTab { threads, agentDetail, fileSystem }
```

### Refaktor `AdditionalColumn`

Przebudowa `additional_column.dart` na komponent tabbed:

```dart
class AdditionalColumn extends ConsumerStatefulWidget {
  const AdditionalColumn({
    super.key,
    this.selectedThreadId,
    this.onClearThreadSelection,
  });

  final String? selectedThreadId;
  final VoidCallback? onClearThreadSelection;
}
```

**Logika zakładek:**
- **Tab 1 "Threads"** — aktywna gdy `selectedThreadId != null` OR zawsze dostępna; zawartość: istniejący `_ThreadView` (gdy thread wybrany) lub lista wątków sesji
- **Tab 2 "Agent"** — dostępna gdy `selectedAgentDetailProvider` ma dane; zawartość: nowy `_AgentDetailView`
- **Tab 3 "Files"** — zawsze widoczna jako zakładka, ale zawartość: placeholder "Coming soon"

**Nagłówek zakładek** — prosty `TabBar`-style row z 3 ikonami/labelami. Aktywna zakładka: podkreślenie kolorem agenta lub `accentBlue`.

```dart
// Tab bar items:
// [threads icon "Threads"] [person icon "Agent"] [folder icon "Files"]
```

**Auto-switch:** gdy klikniemy agenta w lewej kolumnie → automatycznie przejdź do Tab 2. Gdy klikniemy thread w konwersacji → Tab 1.

### Nowy widget `_AgentDetailView`

**`lib/ui/screens/chat_workspace/additional/agent_detail_view.dart`** — NOWY:

Pokazuje dane z `AgentDetail`:
```dart
class AgentDetailView extends ConsumerWidget {
  // Czyta z selectedAgentDetailProvider
  // Loading state → skeleton
  // Error → error placeholder
  // Data → układ:
  //   - AgentAvatar (duży, ~72px) + name + model badge
  //   - description (body text)
  //   - system_prompt (collapsible, kod/mono font, max 200 znaków z "show more")
  //   - tools list (chropy/badges z nazwami narzędzi)
}
```

Jeśli `selectedAgentDetailProvider` zwraca null (brak wybranego agenta) → empty state: "Wybierz agenta z listy po lewej".

---

## 4. Attachment download

### Model

**`lib/features/sessions/domain/session_attachment.dart`** — sprawdzić czy istnieje; jeśli nie, NOWY:
```dart
class SessionAttachment {
  const SessionAttachment({
    required this.id,
    required this.fileName,
    required this.mediaType,
    required this.sizeBytes,
    required this.path,  // virtual path np. "workspace/files/raport.pdf"
  });
  final String id;
  final String fileName;
  final String mediaType;
  final int sizeBytes;
  final String path;
}
```

### Download service

**`lib/features/sessions/data/attachment_download_service.dart`** — NOWY:
```dart
class AttachmentDownloadService {
  AttachmentDownloadService({required ManfredApiClient apiClient})
    : _apiClient = apiClient;

  Future<void> downloadFile({
    required String sessionId,
    required String virtualPath,
    required String fileName,
  }) async {
    // GET /sessions/{sessionId}/files/download?path={virtualPath}
    // Na web: otwieramy URL w nowym oknie (url_launcher lub html.window.open)
    // Na desktop/mobile: getBytes() → zapisz przez file_saver lub share_plus
    final bytes = await _apiClient.getBytes(
      '/sessions/$sessionId/files/download',
      queryParams: {'path': virtualPath},
    );
    // Platform-specific save/open...
  }
}

final attachmentDownloadServiceProvider = Provider<AttachmentDownloadService>((ref) {
  return AttachmentDownloadService(apiClient: ref.watch(manfredApiClientProvider));
});
```

**Uwaga:** `ManfredApiClient` może nie mieć `getBytes()` — dodać metodę jeśli brak.

### UI — Attachment chip w wiadomości agenta

Attachmenty są polami w `SessionItem` / `AgentConversationEntry` (lub zwracane jako osobny typ).

**Format backendu — assumption:** Backend zwróci attachment jako pole w `SessionItem` (podobnie jak user attachments). Jeśli backend nie implementuje jeszcze tego, `AttachmentChip` nie pojawi się — graceful degradation.

**`lib/ui/screens/chat_workspace/conversation/items/agent_message_item.dart`** — MODYFIKACJA:
- Jeśli `entry.attachments.isNotEmpty` → renderuj listę `AttachmentChip`ów pod tekstem

**`lib/ui/core/attachment_chip.dart`** — NOWY:
```dart
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({required this.attachment, required this.onDownload});
  final SessionAttachment attachment;
  final VoidCallback onDownload;

  // Wygląd: icon(paperclip) + fileName + rozmiar + download icon
  // Tap → onDownload()
}
```

**W `AgentMessageItem`:**
```dart
onDownload: () {
  ref.read(attachmentDownloadServiceProvider).downloadFile(
    sessionId: sessionId,
    virtualPath: attachment.path,
    fileName: attachment.fileName,
  );
}
```

---

## Nowe pliki

| Plik | Akcja |
|------|-------|
| `lib/features/agents/domain/agent_summary.dart` | NOWY |
| `lib/features/agents/domain/agent_detail.dart` | NOWY |
| `lib/features/agents/domain/right_panel_tab.dart` | NOWY |
| `lib/features/agents/data/agents_dto.dart` | NOWY |
| `lib/features/agents/data/agents_repository.dart` | NOWY |
| `lib/features/agents/application/agents_list_provider.dart` | NOWY |
| `lib/features/agents/application/selected_agent_provider.dart` | NOWY |
| `lib/features/sessions/application/sessions_list_provider.dart` | MODYFIKACJA (filtr po agencie) |
| `lib/ui/screens/chat_workspace/columns/agent_column.dart` | MODYFIKACJA (ConsumerWidget, real data) |
| `lib/ui/screens/chat_workspace/columns/additional_column.dart` | MODYFIKACJA (tabbed) |
| `lib/ui/screens/chat_workspace/additional/agent_detail_view.dart` | NOWY |
| `lib/ui/core/attachment_chip.dart` | NOWY |
| `lib/features/sessions/data/attachment_download_service.dart` | NOWY |
| `lib/features/sessions/domain/session_attachment.dart` | NOWY (jeśli nie istnieje) |
| `lib/core/api/manfred_api_client.dart` | MODYFIKACJA: dodać getBytes() jeśli brak |

---

## Kolejność implementacji

1. **Domain models + DTO** (AgentSummary, AgentDetail — czyste klasy, zero zależności)
2. **Repository + providers** (AgentsRepository, agentsListProvider, selectedAgentProvider)
3. **Agent column** — podpiąć do providerów, usunąć mock zależność
4. **Right panel tabs** — refaktor AdditionalColumn + AgentDetailView
5. **Attachment chip + download service** (można równolegle z 3-4)

---

## Zależności zewnętrzne

- Brak nowych pakietów Flutter (Riverpod już jest)
- `file_saver` lub `universal_io` może być potrzebne do pobrania pliku na desktopie — sprawdzić co jest w pubspec, jeśli brak dodać i zaktualizować `pubspec.yaml`
- Na web: `dart:html` lub `url_launcher` do otwarcia URL pobierania
