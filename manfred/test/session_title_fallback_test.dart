import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/sessions/data/sessions_dto.dart';
import 'package:manfred/features/sessions/domain/session_details.dart';
import 'package:manfred/features/sessions/domain/session_list_entry.dart';

void main() {
  test('session list entry falls back to createdAt when title is empty', () {
    final entry = SessionListEntry(
      id: 'session-1',
      userId: 'user-1',
      title: '   ',
      status: 'active',
      rootAgentId: 'agent-1',
      rootAgentName: 'Manfred',
      rootAgentStatus: 'active',
      waitingForCount: 0,
      lastMessagePreview: null,
      createdAt: DateTime(2026, 4, 27, 14, 35),
      updatedAt: DateTime(2026, 4, 27, 14, 36),
    );

    expect(entry.displayTitle, '27.04.2026 14:35');
  });

  test('session summary falls back to createdAt when title is missing', () {
    final summary = SessionSummary(
      id: 'session-1',
      userId: 'user-1',
      title: null,
      status: 'active',
      createdAt: DateTime(2026, 4, 27, 14, 35),
      updatedAt: DateTime(2026, 4, 27, 14, 36),
    );

    expect(summary.displayTitle, '27.04.2026 14:35');
  });

  test('session title fallback converts UTC time to local user time', () {
    final createdAtUtc = DateTime.utc(2026, 4, 27, 12, 35);
    final expectedTitle = _formatLocal(createdAtUtc.toLocal());

    final entry = SessionListEntry(
      id: 'session-1',
      userId: 'user-1',
      title: null,
      status: 'active',
      rootAgentId: 'agent-1',
      rootAgentName: 'Manfred',
      rootAgentStatus: 'active',
      waitingForCount: 0,
      lastMessagePreview: null,
      createdAt: createdAtUtc,
      updatedAt: createdAtUtc,
    );
    final summary = SessionSummary(
      id: 'session-1',
      userId: 'user-1',
      title: null,
      status: 'active',
      createdAt: createdAtUtc,
      updatedAt: createdAtUtc,
    );

    expect(entry.displayTitle, expectedTitle);
    expect(summary.displayTitle, expectedTitle);
  });

  test(
    'session dto treats timezone-less timestamps as UTC before formatting title',
    () {
      final createdAtUtc = DateTime.utc(2026, 4, 27, 5, 33);
      final expectedTitle = _formatLocal(createdAtUtc.toLocal());
      final entry = SessionListEntryDto.fromJson(<String, dynamic>{
        'id': 'session-1',
        'user_id': 'user-1',
        'title': null,
        'status': 'active',
        'root_agent_id': 'agent-1',
        'root_agent_name': 'Manfred',
        'root_agent_status': 'active',
        'waiting_for_count': 0,
        'last_message_preview': null,
        'created_at': '2026-04-27T05:33:00',
        'updated_at': '2026-04-27T05:33:00',
      }).toDomain();

      expect(entry.displayTitle, expectedTitle);
    },
  );
}

String _formatLocal(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}
