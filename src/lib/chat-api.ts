import type {
  AttachmentKind,
  AgentItem,
  ChatAttachment,
  ChatAttachmentTranscription,
} from '../types/chat'

const apiBaseUrl = (import.meta.env.API_BASE_URL ?? '').replace(/\/+$/, '')

export const chatCompletionsEndpointPath = '/api/v1/chat/completions'
export const chatAttachmentsEndpointPath = '/api/v1/chat/attachments'
export const chatCompletionsEndpointLabel = apiBaseUrl
  ? `${apiBaseUrl}${chatCompletionsEndpointPath}`
  : chatCompletionsEndpointPath
export const chatAttachmentsEndpointLabel = apiBaseUrl
  ? `${apiBaseUrl}${chatAttachmentsEndpointPath}`
  : chatAttachmentsEndpointPath

interface ChatCompletionPayload {
  message?: string
  sessionId?: string | null
  attachmentIds?: string[]
}

export interface ChatCompletionResponse {
  sessionId: string | null
  agentId: string
  parentAgentId?: string
  depth?: number
  agentName?: string
  output: unknown[]
  items: AgentItem[]
  message: string
}

export interface UploadAttachmentsPayload {
  files: File[]
  sessionId?: string | null
}

export interface UploadAttachmentsResponse {
  sessionId: string | null
  attachments: ChatAttachment[]
}

interface ValidationError {
  loc?: Array<number | string>
  msg?: string
}

interface ErrorResponsePayload {
  detail?: unknown
  message?: unknown
}

interface RawChatCompletionResponse {
  sessionId?: unknown
  session_id?: unknown
  agentId?: unknown
  agent_id?: unknown
  parentAgentId?: unknown
  parent_agent_id?: unknown
  depth?: unknown
  agentName?: unknown
  agent_name?: unknown
  output?: unknown
}

interface RawUploadResponse {
  sessionId?: unknown
  session_id?: unknown
  attachments?: unknown
  attachment?: unknown
}

interface RawAttachment {
  id?: unknown
  kind?: unknown
  mimeType?: unknown
  mime_type?: unknown
  originalFilename?: unknown
  original_filename?: unknown
  filename?: unknown
  name?: unknown
  workspacePath?: unknown
  workspace_path?: unknown
  path?: unknown
  sizeBytes?: unknown
  size_bytes?: unknown
  size?: unknown
  transcription?: unknown
}

interface RawTextValue {
  value?: unknown
}

interface RawOutputItem {
  id?: unknown
  type?: unknown
  text?: unknown
  summary?: unknown
  content?: unknown
  name?: unknown
  callId?: unknown
  call_id?: unknown
  arguments?: unknown
  output?: unknown
  isError?: unknown
  is_error?: unknown
  metadata?: unknown
}

export class ChatApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ChatApiError'
    this.status = status
  }
}

const isChatApiDebugEnabled =
  import.meta.env.DEV || import.meta.env.VITE_CHAT_API_DEBUG === 'true'

const debugChatApi = (event: string, payload: unknown) => {
  if (!isChatApiDebugEnabled) {
    return
  }

  console.debug(`[chat-api] ${event}`, payload)
}

const errorChatApi = (event: string, payload: unknown) => {
  console.error(`[chat-api] ${event}`, payload)
}

const extractErrorMessage = (payload: ErrorResponsePayload | null) => {
  if (!payload) {
    return null
  }

  if (typeof payload.message === 'string' && payload.message.length > 0) {
    return payload.message
  }

  if (typeof payload.detail === 'string' && payload.detail.length > 0) {
    return payload.detail
  }

  if (Array.isArray(payload.detail) && payload.detail.length > 0) {
    return payload.detail
      .map((item) => (item as ValidationError).msg)
      .filter((value): value is string => typeof value === 'string' && value.length > 0)
      .join(' ')
  }

  return null
}

const readErrorResponse = async (response: Response) => {
  const rawBody = await response.text()
  const trimmedBody = rawBody.trim()

  if (trimmedBody.length === 0) {
    return {
      message: null,
      rawBody: null,
      parsedBody: null,
    }
  }

  try {
    const parsedBody = JSON.parse(trimmedBody) as ErrorResponsePayload

    return {
      message: extractErrorMessage(parsedBody),
      rawBody: trimmedBody,
      parsedBody,
    }
  } catch {
    return {
      message: trimmedBody,
      rawBody: trimmedBody,
      parsedBody: null,
    }
  }
}

const readSessionId = (value: { sessionId?: unknown; session_id?: unknown }) => {
  const sessionId = value.sessionId ?? value.session_id

  return typeof sessionId === 'string' && sessionId.length > 0 ? sessionId : null
}

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

const ensureObjectRecord = (value: unknown) =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined

const inferAttachmentKind = (mimeType: string): AttachmentKind => {
  if (mimeType.startsWith('image/')) {
    return 'image'
  }

  if (mimeType.startsWith('audio/')) {
    return 'audio'
  }

  if (
    mimeType === 'application/pdf' ||
    mimeType.startsWith('text/') ||
    mimeType.includes('document') ||
    mimeType.includes('sheet') ||
    mimeType.includes('presentation')
  ) {
    return 'document'
  }

  return 'other'
}

const normalizeTranscription = (
  value: unknown,
): ChatAttachmentTranscription | undefined => {
  if (!value || typeof value !== 'object') {
    return undefined
  }

  const rawTranscription = value as { status?: unknown; text?: unknown }

  if (
    rawTranscription.status !== 'not_applicable' &&
    rawTranscription.status !== 'pending' &&
    rawTranscription.status !== 'completed' &&
    rawTranscription.status !== 'failed'
  ) {
    return undefined
  }

  const status = rawTranscription.status

  return {
    status,
    text: typeof rawTranscription.text === 'string' ? rawTranscription.text : undefined,
  }
}

const normalizeAttachment = (value: unknown): ChatAttachment => {
  if (!value || typeof value !== 'object') {
    throw new ChatApiError('Backend zwrocil nieprawidlowe dane attachmentu.', 500)
  }

  const rawAttachment = value as RawAttachment
  const id = rawAttachment.id
  const mimeType = rawAttachment.mimeType ?? rawAttachment.mime_type
  const originalFilename =
    rawAttachment.originalFilename ??
    rawAttachment.original_filename ??
    rawAttachment.filename ??
    rawAttachment.name
  const workspacePath =
    rawAttachment.workspacePath ?? rawAttachment.workspace_path ?? rawAttachment.path
  const sizeBytes = rawAttachment.sizeBytes ?? rawAttachment.size_bytes ?? rawAttachment.size
  const parsedSizeBytes =
    typeof sizeBytes === 'number'
      ? sizeBytes
      : typeof sizeBytes === 'string'
        ? Number(sizeBytes)
        : Number.NaN

  if (
    typeof id !== 'string' ||
    typeof mimeType !== 'string' ||
    typeof originalFilename !== 'string' ||
    typeof workspacePath !== 'string' ||
    Number.isNaN(parsedSizeBytes)
  ) {
    throw new ChatApiError('Backend zwrocil niepelne metadane attachmentu.', 500)
  }

  const kind =
    rawAttachment.kind === 'image' ||
    rawAttachment.kind === 'document' ||
    rawAttachment.kind === 'audio' ||
    rawAttachment.kind === 'other'
      ? rawAttachment.kind
      : inferAttachmentKind(mimeType)

  return {
    id,
    kind,
    mimeType,
    originalFilename,
    workspacePath,
    sizeBytes: parsedSizeBytes,
    transcription: normalizeTranscription(rawAttachment.transcription),
  }
}

const collectOutputText = (value: unknown): string[] => {
  if (!value) {
    return []
  }

  if (typeof value === 'string') {
    return value.length > 0 ? [value] : []
  }

  if (Array.isArray(value)) {
    return value.flatMap((item) => collectOutputText(item))
  }

  if (typeof value !== 'object') {
    return []
  }

  const item = value as {
    type?: unknown
    text?: unknown
    content?: unknown
  }
  const textValue =
    typeof item.text === 'string'
      ? item.text
      : item.text && typeof item.text === 'object'
        ? (item.text as RawTextValue).value
        : undefined

  const texts: string[] = []

  if (
    (item.type === 'text' || item.type === 'output_text' || typeof item.type === 'undefined') &&
    typeof textValue === 'string' &&
    textValue.length > 0
  ) {
    texts.push(textValue)
  }

  if (item.content) {
    texts.push(...collectOutputText(item.content))
  }

  return texts
}

const safeParseJson = (value: string) => {
  try {
    return JSON.parse(value) as unknown
  } catch {
    return value
  }
}

const readTextValue = (value: unknown): string | undefined => {
  if (typeof value === 'string' && value.length > 0) {
    return value
  }

  if (value && typeof value === 'object') {
    const rawTextValue = value as RawTextValue

    return typeof rawTextValue.value === 'string' && rawTextValue.value.length > 0
      ? rawTextValue.value
      : undefined
  }

  return undefined
}

const readContentText = (value: unknown): string | undefined => {
  const texts = collectOutputText(value)

  return texts.length > 0 ? texts.join('\n\n').trim() : undefined
}

const normalizeReasoningMetadata = (value: unknown) => {
  const metadata = ensureObjectRecord(value)

  return metadata && Object.keys(metadata).length > 0 ? metadata : undefined
}

const normalizeToolArguments = (value: unknown) => {
  if (typeof value === 'string') {
    return safeParseJson(value)
  }

  return value
}

const normalizeToolOutput = (value: unknown) => {
  if (typeof value === 'string') {
    return safeParseJson(value)
  }

  return value
}

const createUnknownItem = (raw: unknown): AgentItem => ({
  id: crypto.randomUUID(),
  type: 'unknown',
  raw,
})

export const normalizeOutputItem = (raw: unknown): AgentItem[] => {
  if (!raw || typeof raw !== 'object') {
    return [createUnknownItem(raw)]
  }

  const item = raw as RawOutputItem
  const id = readOptionalString(item.id) ?? crypto.randomUUID()
  const type = readOptionalString(item.type)
  const text = readTextValue(item.text)
  const contentText = readContentText(item.content)
  const summary = readTextValue(item.summary)
  const name = readOptionalString(item.name)
  const callId = readOptionalString(item.callId ?? item.call_id)

  switch (type) {
    case 'text':
    case 'output_text':
    case 'assistant_message': {
      const normalizedText = text ?? contentText

      return normalizedText
        ? [
            {
              id,
              type: 'text',
              text: normalizedText,
            },
          ]
        : [createUnknownItem(raw)]
    }
    case 'reasoning':
    case 'reasoning_summary': {
      if (!text && !summary) {
        return [createUnknownItem(raw)]
      }

      return [
        {
          id,
          type: 'reasoning',
          text,
          summary,
          metadata: normalizeReasoningMetadata(item.metadata),
        },
      ]
    }
    case 'function_call':
    case 'tool_call': {
      if (!callId || !name) {
        return [createUnknownItem(raw)]
      }

      return [
        {
          id,
          type: 'function_call',
          callId,
          name,
          arguments: normalizeToolArguments(item.arguments),
        },
      ]
    }
    case 'function_call_output':
    case 'tool_result': {
      if (!callId) {
        return [createUnknownItem(raw)]
      }

      return [
        {
          id,
          type: 'function_call_output',
          callId,
          name,
          output: normalizeToolOutput(item.output),
          isError:
            typeof item.isError === 'boolean'
              ? item.isError
              : typeof item.is_error === 'boolean'
                ? item.is_error
                : undefined,
        },
      ]
    }
    case 'message': {
      if (!Array.isArray(item.content)) {
        return [createUnknownItem(raw)]
      }

      const nestedItems = item.content.flatMap((contentItem) => normalizeOutputItem(contentItem))

      return nestedItems.length > 0 ? nestedItems : [createUnknownItem(raw)]
    }
    default: {
      if (!type && (text ?? contentText)) {
        return [
          {
            id,
            type: 'text',
            text: text ?? contentText ?? '',
          },
        ]
      }

      return [createUnknownItem(raw)]
    }
  }
}

export const normalizeAgentItems = (rawOutput: unknown[]): AgentItem[] => {
  const normalizedItems = rawOutput.flatMap((rawItem) => normalizeOutputItem(rawItem))

  return normalizedItems.length > 0 ? normalizedItems : []
}

export const sendChatCompletion = async (
  payload: ChatCompletionPayload,
  signal?: AbortSignal,
): Promise<ChatCompletionResponse> => {
  const requestBody = {
    sessionId: payload.sessionId ?? undefined,
    message: payload.message ?? '',
    attachmentIds: payload.attachmentIds ?? [],
  }

  debugChatApi('chat.completions.request', {
    url: chatCompletionsEndpointLabel,
    sessionId: requestBody.sessionId ?? null,
    attachmentIds: requestBody.attachmentIds,
    messageLength: requestBody.message.length,
    messagePreview: requestBody.message.slice(0, 200),
  })

  const response = await fetch(chatCompletionsEndpointLabel, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
    signal,
  })

  if (!response.ok) {
    const { message, rawBody, parsedBody } = await readErrorResponse(response)

    errorChatApi('chat.completions.error', {
      url: chatCompletionsEndpointLabel,
      status: response.status,
      statusText: response.statusText,
      request: {
        sessionId: requestBody.sessionId ?? null,
        attachmentIds: requestBody.attachmentIds,
        messageLength: requestBody.message.length,
        messagePreview: requestBody.message.slice(0, 200),
      },
      responseBody: parsedBody ?? rawBody,
    })

    throw new ChatApiError(
      message ?? `Backend czatu zwrocil blad HTTP ${response.status}.`,
      response.status,
    )
  }

  const data = (await response.json()) as RawChatCompletionResponse
  const output = Array.isArray(data.output) ? data.output : []
  const items = normalizeAgentItems(output)

  debugChatApi('chat.completions.response', {
    url: chatCompletionsEndpointLabel,
    status: response.status,
    sessionId: readSessionId(data),
    agentId: readOptionalString(data.agentId ?? data.agent_id) ?? 'assistant',
    outputCount: output.length,
    normalizedItemCount: items.length,
  })

  return {
    sessionId: readSessionId(data),
    agentId: readOptionalString(data.agentId ?? data.agent_id) ?? 'assistant',
    parentAgentId: readOptionalString(data.parentAgentId ?? data.parent_agent_id),
    depth: readOptionalNumber(data.depth),
    agentName: readOptionalString(data.agentName ?? data.agent_name),
    output,
    items,
    message: items
      .filter((item): item is Extract<AgentItem, { type: 'text' }> => item.type === 'text')
      .map((item) => item.text)
      .join('\n\n')
      .trim(),
  }
}

export const uploadAttachments = async (
  payload: UploadAttachmentsPayload,
  signal?: AbortSignal,
): Promise<UploadAttachmentsResponse> => {
  const formData = new FormData()

  payload.files.forEach((file) => {
    formData.append('files', file, file.name)
  })

  if (payload.sessionId) {
    formData.append('sessionId', payload.sessionId)
  }

  debugChatApi('chat.attachments.request', {
    url: chatAttachmentsEndpointLabel,
    sessionId: payload.sessionId ?? null,
    files: payload.files.map((file) => ({
      name: file.name,
      size: file.size,
      type: file.type,
    })),
  })

  const response = await fetch(chatAttachmentsEndpointLabel, {
    method: 'POST',
    body: formData,
    signal,
  })

  if (!response.ok) {
    const { message, rawBody, parsedBody } = await readErrorResponse(response)

    errorChatApi('chat.attachments.error', {
      url: chatAttachmentsEndpointLabel,
      status: response.status,
      statusText: response.statusText,
      request: {
        sessionId: payload.sessionId ?? null,
        fileCount: payload.files.length,
        files: payload.files.map((file) => ({
          name: file.name,
          size: file.size,
          type: file.type,
        })),
      },
      responseBody: parsedBody ?? rawBody,
    })

    throw new ChatApiError(
      message ?? `Backend attachmentow zwrocil blad HTTP ${response.status}.`,
      response.status,
    )
  }

  const data = (await response.json()) as RawUploadResponse
  const rawAttachments = Array.isArray(data.attachments)
    ? data.attachments
    : data.attachment
      ? [data.attachment]
      : []

  const normalizedAttachments = rawAttachments.map((attachment) => normalizeAttachment(attachment))

  debugChatApi('chat.attachments.response', {
    url: chatAttachmentsEndpointLabel,
    status: response.status,
    sessionId: readSessionId(data),
    attachmentCount: normalizedAttachments.length,
  })

  return {
    sessionId: readSessionId(data),
    attachments: normalizedAttachments,
  }
}
