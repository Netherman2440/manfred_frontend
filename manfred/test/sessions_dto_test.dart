import 'package:flutter_test/flutter_test.dart';
import 'package:manfred/features/sessions/data/sessions_dto.dart';
import 'package:manfred/features/sessions/domain/session_item.dart';

void main() {
  test('maps transcript message attachments and edit metadata', () {
    final details = SessionDetailsResponseDto.fromJson(<String, dynamic>{
      'data': <String, dynamic>{
        'session': <String, dynamic>{
          'id': 'session-1',
          'user_id': 'user-1',
          'title': 'chat',
          'status': 'active',
          'created_at': '2026-04-30T10:00:00Z',
          'updated_at': '2026-04-30T10:02:00Z',
        },
        'root_agent': <String, dynamic>{
          'id': 'agent-1',
          'name': 'Manfred',
          'status': 'completed',
          'model': 'openrouter:test',
          'waiting_for': const <Object?>[],
        },
        'items': <Object?>[
          <String, dynamic>{
            'id': 'item-1',
            'type': 'message',
            'agent_id': 'agent-1',
            'sequence': 1,
            'created_at': '2026-04-30T10:01:00Z',
            'role': 'user',
            'content': 'Prześlij brief.',
            'is_edited': true,
            'edited_at': '2026-04-30T10:01:30Z',
            'attachments': <Object?>[
              <String, dynamic>{
                'id': 'attachment-1',
                'file_name': 'brief.pdf',
                'media_type': 'application/pdf',
                'size_bytes': 4096,
                'path': '/uploads/brief.pdf',
              },
            ],
          },
        ],
      },
    }).data.toDomain();

    final message = details.items.single as SessionMessageItem;
    expect(message.isEdited, isTrue);
    expect(message.editedAt, isNotNull);
    expect(message.attachments, hasLength(1));
    expect(message.attachments.single.fileName, 'brief.pdf');
    expect(message.attachments.single.mediaType, 'application/pdf');
  });
}
