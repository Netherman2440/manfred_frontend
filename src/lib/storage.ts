import type {
  AgentItem,
  AgentResponse,
  ChatAttachment,
  ChatAttachmentTranscription,
  ChatEntry,
} from '../types/chat'

const storageKey = 'manfred-chat-state'

interface StoredChatState {
  sessionId: string | null
  entries: ChatEntry[]
}

interface LegacyStoredChatState {
  sessionId: string | null
  messages?: unknown
  entries?: unknown
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value)

const readOptionalString = (value: unknown) =>
  typeof value === 'string' && value.length > 0 ? value : undefined

const readOptionalNumber = (value: unknown) => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }

  if (typeof value === 'string' && value.trim().length > 0) {
    const parsedValue = Number(value)

    return Number.isFinite(parsedValue) ? parsedValue : undefined
  }

  return undefined
}

const normalizeAttachment = (value: unknown): ChatAttachment | null => {
  if (!isRecord(value)) {
    return null
  }

  const id = readOptionalString(value.id)
  const kind = value.kind
  const mimeType = readOptionalString(value.mimeType)
  const originalFilename = readOptionalString(value.originalFilename)
  const workspacePath = readOptionalString(value.workspacePath)
  const sizeBytes = readOptionalNumber(value.sizeBytes)

  if (
    !id ||
    (kind !== 'image' &&
      kind !== 'document' &&
      kind !== 'audio' &&
      kind !== 'other') ||
    !mimeType ||
    !originalFilename ||
    !workspacePath ||
    typeof sizeBytes !== 'number'
  ) {
    return null
  }

  const transcription: ChatAttachmentTranscription | undefined = isRecord(value.transcription)
    ? value.transcription.status === 'pending' ||
      value.transcription.status === 'completed' ||
      value.transcription.status === 'failed'
      ? {
          status: value.transcription.status,
          text: readOptionalString(value.transcription.text),
        }
      : undefined
    : undefined

  return {
    id,
    kind,
    mimeType,
    originalFilename,
    workspacePath,
    sizeBytes,
    transcription,
  }
}

const normalizeAttachments = (value: unknown) => {
  if (!Array.isArray(value)) {
    return undefined
  }

  const attachments = value
    .map((attachment) => normalizeAttachment(attachment))
    .filter((attachment): attachment is ChatAttachment => attachment !== null)

  return attachments.length > 0 ? attachments : undefined
}

const normalizeAgentItem = (value: unknown): AgentItem | null => {
  if (!isRecord(value)) {
    return null
  }

  const id = readOptionalString(value.id)
  const type = value.type

  if (!id || typeof type !== 'string') {
    return null
  }

  switch (type) {
    case 'text': {
      const text = readOptionalString(value.text)

      return text
        ? {
            id,
            type: 'text',
            text,
          }
        : null
    }
    case 'reasoning': {
      const text = readOptionalString(value.text)
      const summary = readOptionalString(value.summary)

      return text || summary
        ? {
            id,
            type: 'reasoning',
            text,
            summary,
            metadata: isRecord(value.metadata) ? value.metadata : undefined,
          }
        : null
    }
    case 'function_call': {
      const callId = readOptionalString(value.callId)
      const name = readOptionalString(value.name)

      return callId && name
        ? {
            id,
            type: 'function_call',
            callId,
            name,
            arguments: value.arguments,
          }
        : null
    }
    case 'function_call_output': {
      const callId = readOptionalString(value.callId)
      const name = readOptionalString(value.name)

      return callId
        ? {
            id,
            type: 'function_call_output',
            callId,
            name,
            output: value.output,
            isError: typeof value.isError === 'boolean' ? value.isError : undefined,
          }
        : null
    }
    case 'unknown':
      return {
        id,
        type: 'unknown',
        raw: value.raw,
      }
    default:
      return null
  }
}

const createLegacyAssistantResponse = (
  legacyMessage: Record<string, unknown>,
  sessionId: string | null,
): AgentResponse | null => {
  const id = readOptionalString(legacyMessage.id)
  const content = readOptionalString(legacyMessage.content)
  const createdAt = readOptionalString(legacyMessage.createdAt)

  if (!id || !createdAt) {
    return null
  }

  return {
    id,
    entryType: 'agent_response',
    sessionId,
    agentId: 'assistant',
    role: 'assistant',
    createdAt,
    items: content
      ? [
          {
            id: `${id}-text`,
            type: 'text',
            text: content,
          },
        ]
      : [],
  }
}

const normalizeStoredEntry = (
  value: unknown,
  sessionId: string | null,
): ChatEntry | null => {
  if (!isRecord(value)) {
    return null
  }

  if (value.entryType === 'agent_response') {
    const id = readOptionalString(value.id)
    const createdAt = readOptionalString(value.createdAt)

    if (!id || !createdAt) {
      return null
    }

    return {
      id,
      entryType: 'agent_response',
      sessionId:
        value.sessionId === null || typeof value.sessionId === 'string'
          ? value.sessionId
          : sessionId,
      agentId: readOptionalString(value.agentId) ?? 'assistant',
      parentAgentId: readOptionalString(value.parentAgentId),
      depth: readOptionalNumber(value.depth),
      agentName: readOptionalString(value.agentName),
      role: 'assistant',
      createdAt,
      items: Array.isArray(value.items)
        ? value.items
            .map((item) => normalizeAgentItem(item))
            .filter((item): item is AgentItem => item !== null)
        : [],
    }
  }

  if (value.entryType === 'message') {
    const id = readOptionalString(value.id)
    const content = typeof value.content === 'string' ? value.content : ''
    const createdAt = readOptionalString(value.createdAt)

    if (!id || !createdAt || value.role !== 'user') {
      return null
    }

    return {
      id,
      entryType: 'message',
      role: 'user',
      content,
      createdAt,
      attachments: normalizeAttachments(value.attachments),
    }
  }

  if (value.role === 'assistant') {
    return createLegacyAssistantResponse(value, sessionId)
  }

  if (value.role !== 'user') {
    return null
  }

  const id = readOptionalString(value.id)
  const createdAt = readOptionalString(value.createdAt)

  if (!id || !createdAt) {
    return null
  }

  return {
    id,
    entryType: 'message',
    role: 'user',
    content: typeof value.content === 'string' ? value.content : '',
    createdAt,
    attachments: normalizeAttachments(value.attachments),
  }
}

export const loadStoredChatState = (): StoredChatState | null => {
  try {
    const rawValue = window.localStorage.getItem(storageKey)

    if (!rawValue) {
      return null
    }

    const parsedValue = JSON.parse(rawValue) as LegacyStoredChatState

    if (
      !parsedValue ||
      typeof parsedValue !== 'object' ||
      !('sessionId' in parsedValue) ||
      (parsedValue.sessionId !== null && typeof parsedValue.sessionId !== 'string') ||
      (!Array.isArray(parsedValue.entries) && !Array.isArray(parsedValue.messages))
    ) {
      return null
    }

    const rawEntries = Array.isArray(parsedValue.entries)
      ? parsedValue.entries
      : Array.isArray(parsedValue.messages)
        ? parsedValue.messages
        : []

    return {
      sessionId: parsedValue.sessionId,
      entries: rawEntries
        .map((entry) => normalizeStoredEntry(entry, parsedValue.sessionId))
        .filter((entry): entry is ChatEntry => entry !== null),
    }
  } catch {
    return null
  }
}

export const saveStoredChatState = (state: StoredChatState) => {
  try {
    window.localStorage.setItem(storageKey, JSON.stringify(state))
  } catch {
    return
  }
}

export const clearStoredChatState = () => {
  try {
    window.localStorage.removeItem(storageKey)
  } catch {
    return
  }
}
