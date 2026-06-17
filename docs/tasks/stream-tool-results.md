# Stream tool lifecycle over SSE — frontend

## Goal

Consume the new SSE tool events (`tool.called`, `tool.completed`, `tool.failed`) and show tool
results live in the chat, instead of only after the run finishes / on history reload.

The UI and domain model already exist: `ToolCallItem` renders a tool call with an output preview,
and `SessionToolResultItem` (`features/sessions/domain/session_item.dart`) holds
`callId / name / toolResult / isError`. They are simply never fed during a streaming run — only
the tool *call* (`function_call_done`) is streamed today, never the *result*.

## SSE event shapes (from backend)

`tool.called`  → `{ call_id, name, agent_id, parent_agent_id, depth, arguments }`
`tool.completed` → `{ call_id, name, agent_id, parent_agent_id, depth, duration_ms, is_error:false, tool_result }`
`tool.failed`  → `{ call_id, name, agent_id, parent_agent_id, depth, duration_ms, is_error:true,  tool_result }`

`tool_result` is the full result dict, identical to the sessions-history `tool_result` field, so a
live item and a reloaded item map to the same `SessionToolResultItem.toolResult`.

## Changes

### 1. New stream-event DTOs (`features/chat/domain/chat_stream_event.dart`)

Add sealed subclasses of `ChatStreamEvent`:

- `ChatToolCalledStreamEvent { callId, name, agentId, parentAgentId, depth, arguments }`
- `ChatToolCompletedStreamEvent { callId, name, agentId, depth, durationMs, toolResult, isError }`
- `ChatToolFailedStreamEvent { callId, name, agentId, depth, durationMs, toolResult, isError }`

### 2. Dispatch (`features/chat/data/chat_repository.dart`, `_mapStreamEvent`)

Add `case` handlers for the three `type` strings, reading the fields above (`tool_result`,
`is_error`, `duration_ms`, etc.) and yielding the DTOs. Keep the existing default "ignored" log
for unknown types.

### 3. Consume + UI wiring (composer controller + `session_overlay_providers.dart`)

- `tool.called`: **no-op for rendering.** The tool-call item is already created/updated by the
  existing `function_call_done` → `upsertToolCall` path; do not double-create. (Optional future:
  mark the call pending.)
- `tool.completed` / `tool.failed`: add an `upsertToolResult(...)` method on the overlay
  controller (mirror `upsertToolCall`) that inserts/updates a `SessionToolResultItem` keyed by
  `callId`, with `toolResult` and `isError`. Use a stable local id (e.g.
  `local-tool-result-$sessionId-$callId`) and append after the matching call item.

### 4. Shape parity (load-bearing)

The `SessionToolResultItem` built live must match the one built from history
(`features/sessions/data/sessions_dto.dart` `toDomain()` `function_call_output` case:
`toolResult: json['tool_result']`, `isError: json['is_error']`). Since the backend sends the same
`tool_result` dict, store it as-is — on reload the item is identical, no re-render / jump.

## Verify

- `flutter analyze`
- `flutter test`
- Manual: streaming chat with a tool → result appears live in the tool-call item; reload session →
  unchanged.
