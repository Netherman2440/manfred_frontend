# File Download — frontend

## Cel

Pobieranie plików, które AI dołączył do swojej odpowiedzi. Gdy wiadomość agenta zawiera attachment, użytkownik widzi chip z nazwą pliku — kliknięcie pobiera go przez `GET /sessions/{id}/files/download`.

Dokument wyciąga sekcję 4 ("attachment download") z poprzedniego `agents-column-and-tabs-ui.md` i ją uzupełnia. Tematy agentowe (column, agent detail tab, kreator) są w `agent_templates.md`.

Specyfikacja jest self-contained — nie wymaga zaglądania do backendu.

---

## Kontrakt API

```
GET /api/v1/sessions/{session_id}/files/download?path=<virtual_path>
Response: binary, Content-Disposition: attachment; filename="<name>"
```

`virtual_path` to ścieżka, którą agent widzi w swoich tools (np. `workspace/files/raport.pdf`). Frontend nie buduje jej sam — dostaje ją gotową w polu attachmentu.

Błędy:
- 401 — auth
- 403 — sesja należy do innego usera
- 404 — sesja lub plik nie istnieje
- 413 — plik za duży (cap MAX_FILE_SIZE backendu)

---

## Scope

**In-scope:**
- `SessionAttachment` model (jeśli jeszcze nie istnieje)
- Parsowanie attachmentów z odpowiedzi agenta (`SessionItem` lub `AgentConversationEntry`)
- `AttachmentDownloadService` z platform-specific zapisem (web vs desktop/mobile)
- `AttachmentChip` widget
- Wyrenderowanie chipów pod tekstem agenta w `AgentMessageItem`
- `ManfredApiClient.getBytes()` (jeśli brak)

**Out-of-scope:**
- Podgląd inline (PDF viewer, image preview) — tylko download
- Upload przez użytkownika (osobny task — user attachments)
- Range requests / streaming dużych plików
- Retry po przerwanym pobieraniu

---

## 1. Model i parsowanie

### `SessionAttachment`

Plik: `lib/features/sessions/domain/session_attachment.dart` (NOWY jeśli brak):

```dart
class SessionAttachment {
  const SessionAttachment({
    required this.id,
    required this.fileName,
    required this.mediaType,
    required this.sizeBytes,
    required this.path,
  });

  final String id;
  final String fileName;
  final String mediaType;
  final int sizeBytes;
  final String path;        // virtual path do GET /files/download

  factory SessionAttachment.fromJson(Map<String, dynamic> json) {
    return SessionAttachment(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      mediaType: json['media_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      path: json['path'] as String,
    );
  }
}
```

Backend już ma `AttachmentSchema` (`id`, `file_name`, `media_type`, `size_bytes`, `path`). Reuse pól.

### Parsowanie w wiadomościach agenta

Backend wraca attachment w polu wiadomości agenta. **Schemat dokładnego pola do potwierdzenia w runtime** — przewidywany kontrakt: `SessionItem` agent-text ma opcjonalne `attachments: list[AttachmentSchema]`.

Zmiana w `AgentConversationEntry` (`lib/features/sessions/domain/`):

```dart
class AgentConversationEntry {
  // ... istniejące pola ...
  final List<SessionAttachment> attachments;
}
```

DTO mapping w `sessions_dto.dart` — dodać:
```dart
attachments: (json['attachments'] as List?)
    ?.map((e) => SessionAttachment.fromJson(e as Map<String, dynamic>))
    .toList() ?? const <SessionAttachment>[],
```

Jeśli backend nie wystawia jeszcze attachmentów w odpowiedzi agenta — graceful degradation: pole zawsze jest, ale puste, więc nic nie renderujemy.

---

## 2. Download service

### `AttachmentDownloadService`

Plik: `lib/features/sessions/data/attachment_download_service.dart` (NOWY).

```dart
class AttachmentDownloadService {
  AttachmentDownloadService({required ManfredApiClient apiClient})
      : _apiClient = apiClient;

  final ManfredApiClient _apiClient;

  Future<void> downloadAttachment({
    required String sessionId,
    required SessionAttachment attachment,
  }) async {
    final bytes = await _apiClient.getBytes(
      '/sessions/$sessionId/files/download',
      queryParams: {'path': attachment.path},
    );
    await _saveBytes(
      bytes: bytes,
      fileName: attachment.fileName,
      mediaType: attachment.mediaType,
    );
  }

  Future<void> _saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mediaType,
  }) async {
    if (kIsWeb) {
      _saveBytesWeb(bytes: bytes, fileName: fileName, mediaType: mediaType);
    } else {
      await _saveBytesNative(bytes: bytes, fileName: fileName);
    }
  }
}

final attachmentDownloadServiceProvider = Provider<AttachmentDownloadService>((ref) {
  return AttachmentDownloadService(apiClient: ref.watch(manfredApiClientProvider));
});
```

### Web

```dart
void _saveBytesWeb({
  required Uint8List bytes,
  required String fileName,
  required String mediaType,
}) {
  final blob = html.Blob(<dynamic>[bytes], mediaType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
```

Import via `dart:html` w warstwie web. Aby uniknąć build errorów na desktop/mobile, użyj conditional import:

```dart
// attachment_save_web.dart
import 'dart:html' as html;
void saveBytes({...}) { /* impl */ }

// attachment_save_io.dart
void saveBytes({...}) { throw UnimplementedError(); }

// attachment_save.dart
export 'attachment_save_io.dart' if (dart.library.html) 'attachment_save_web.dart';
```

### Desktop / mobile

Użyć `file_picker` (`saveFile` API) lub `path_provider` + ręczny zapis:

```dart
Future<void> _saveBytesNative({
  required Uint8List bytes,
  required String fileName,
}) async {
  final savePath = await FilePicker.platform.saveFile(
    fileName: fileName,
    bytes: bytes,                      // file_picker przyjmuje bytes na desktopie
  );
  // Na mobile saveFile zwraca path; jeśli null, user anulował
  if (savePath == null) return;
  // Na niektórych platformach `bytes` automatycznie zapisuje plik;
  // jeśli nie, dopisać:
  // await File(savePath).writeAsBytes(bytes);
}
```

Sprawdzić aktualną wersję `file_picker` — `saveFile` z `bytes` jest dostępne od ~6.x na desktopie. Na mobile pakiet `share_plus` z `Share.shareXFiles([XFile.fromData(bytes)])` jest alternatywą; wybór per-platform.

Pakiety w `pubspec.yaml`:
- `file_picker: ^6.x` (już wymagany przez agent_templates)
- `share_plus: ^7.x` (mobile fallback)

### `ManfredApiClient.getBytes`

Jeśli istnieje — używamy. Jeśli nie:

```dart
Future<Uint8List> getBytes(
  String path, {
  Map<String, String>? queryParams,
}) async {
  final uri = _buildUri(path, queryParams);
  final response = await _httpClient.get(uri, headers: _authHeaders());
  if (response.statusCode != 200) {
    throw ManfredApiException(
      statusCode: response.statusCode,
      body: utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }
  return response.bodyBytes;
}
```

`_buildUri`, `_authHeaders` — reuse z istniejącego klienta.

---

## 3. UI — `AttachmentChip`

Plik: `lib/ui/core/attachment_chip.dart` (NOWY).

```dart
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    super.key,
    required this.attachment,
    required this.onDownload,
    this.busy = false,
  });

  final SessionAttachment attachment;
  final VoidCallback onDownload;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ManfredColors.panelAltBackground,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: busy ? null : onDownload,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForMediaType(attachment.mediaType), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attachment.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatSize(attachment.sizeBytes),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForMediaType(String mediaType) {
  if (mediaType.startsWith('image/')) return Icons.image_outlined;
  if (mediaType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mediaType.startsWith('text/')) return Icons.description_outlined;
  return Icons.attach_file;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '${bytes} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
```

### Stan busy

Trzymamy lokalnie w `_AgentMessageItemState` (lub w prowiderze, jeśli wolimy widoczność globalną). Per-attachment:

```dart
final _busyAttachmentIds = <String>{};

Future<void> _downloadAttachment(SessionAttachment attachment) async {
  setState(() => _busyAttachmentIds.add(attachment.id));
  try {
    await ref.read(attachmentDownloadServiceProvider).downloadAttachment(
      sessionId: widget.sessionId,
      attachment: attachment,
    );
  } catch (e) {
    _showSnack('Nie udało się pobrać pliku: $e');
  } finally {
    if (mounted) setState(() => _busyAttachmentIds.remove(attachment.id));
  }
}
```

---

## 4. Integracja z `AgentMessageItem`

Plik: `lib/ui/screens/chat_workspace/conversation/items/agent_message_item.dart`.

Pod tekstem wiadomości:

```dart
if (entry.attachments.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entry.attachments
          .map((attachment) => AttachmentChip(
                attachment: attachment,
                busy: _busyAttachmentIds.contains(attachment.id),
                onDownload: () => _downloadAttachment(attachment),
              ))
          .toList(),
    ),
  ),
```

`sessionId` musi być dostępne w komponencie — zazwyczaj przekazywane z `ConversationColumn` lub wyciągane z `selectedSessionIdProvider`. Sprawdzić aktualny przepływ; jeśli `AgentMessageItem` go nie zna, dodać parametr.

---

## 5. Pliki do stworzenia / zmiany

| Plik | Akcja |
|------|-------|
| `lib/features/sessions/domain/session_attachment.dart` | NOWY (lub potwierdzić istnienie) |
| `lib/features/sessions/data/sessions_dto.dart` | Mapowanie `attachments` w odpowiedzi agenta |
| `lib/features/sessions/data/attachment_download_service.dart` | NOWY |
| `lib/features/sessions/data/attachment_save_io.dart` | NOWY (stub native) |
| `lib/features/sessions/data/attachment_save_web.dart` | NOWY (web impl) |
| `lib/features/sessions/data/attachment_save.dart` | NOWY (conditional export) |
| `lib/ui/core/attachment_chip.dart` | NOWY |
| `lib/ui/screens/chat_workspace/conversation/items/agent_message_item.dart` | Renderowanie chipów + busy state |
| `lib/core/api/manfred_api_client.dart` | `getBytes()` jeśli brak |
| `pubspec.yaml` | `file_picker` (jeśli brak), `share_plus` (mobile fallback, opcjonalnie) |

---

## 6. Kolejność implementacji

1. **`SessionAttachment` model + DTO mapping** — czyste, bez zewnętrznych zależności
2. **`ManfredApiClient.getBytes`** (jeśli brak) — minimalna zmiana w core
3. **`AttachmentDownloadService` szkielet** — bez platform-specific save (just download + log)
4. **Platform save (web)** — conditional import, dart:html
5. **Platform save (native)** — `file_picker.saveFile`
6. **`AttachmentChip`**
7. **Integracja w `AgentMessageItem`** + busy state
8. **Smoke test ręczny**: utworzyć sesję, agent zapisuje plik, sprawdzić chip + download

---

## Out of scope

- Multi-select download (zip wielu plików)
- Pasek postępu dla dużych plików (zwykłe getBytes — pobieramy w całości)
- Auto-otwieranie po pobraniu (np. PDF w nowej karcie) — user sam otwiera plik z folderu
- Drag-out z chip-a do system file managera
- Cache pobranych plików — rezygnujemy, każdy click to nowe pobranie
