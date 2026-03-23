import type {
  AttachmentKind,
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
  output: unknown[]
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

interface RawChatCompletionResponse {
  sessionId?: unknown
  session_id?: unknown
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

export class ChatApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ChatApiError'
    this.status = status
  }
}

const getErrorMessage = async (response: Response) => {
  try {
    const data = (await response.json()) as { detail?: ValidationError[]; message?: string }

    if (typeof data.message === 'string' && data.message.length > 0) {
      return data.message
    }

    if (Array.isArray(data.detail) && data.detail.length > 0) {
      return data.detail
        .map((item) => item.msg)
        .filter((value): value is string => typeof value === 'string' && value.length > 0)
        .join(' ')
    }
  } catch {
    return null
  }

  return null
}

const readSessionId = (value: { sessionId?: unknown; session_id?: unknown }) => {
  const sessionId = value.sessionId ?? value.session_id

  return typeof sessionId === 'string' && sessionId.length > 0 ? sessionId : null
}

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

export const sendChatCompletion = async (
  payload: ChatCompletionPayload,
  signal?: AbortSignal,
): Promise<ChatCompletionResponse> => {
  const response = await fetch(chatCompletionsEndpointLabel, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sessionId: payload.sessionId ?? undefined,
      message: payload.message ?? '',
      attachmentIds: payload.attachmentIds ?? [],
    }),
    signal,
  })

  if (!response.ok) {
    const errorMessage = await getErrorMessage(response)

    throw new ChatApiError(
      errorMessage ?? `Backend czatu zwrocil blad HTTP ${response.status}.`,
      response.status,
    )
  }

  const data = (await response.json()) as RawChatCompletionResponse
  const output = Array.isArray(data.output) ? data.output : []

  return {
    sessionId: readSessionId(data),
    output,
    message: collectOutputText(output).join('\n\n').trim(),
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

  const response = await fetch(chatAttachmentsEndpointLabel, {
    method: 'POST',
    body: formData,
    signal,
  })

  if (!response.ok) {
    const errorMessage = await getErrorMessage(response)

    throw new ChatApiError(
      errorMessage ?? `Backend attachmentow zwrocil blad HTTP ${response.status}.`,
      response.status,
    )
  }

  const data = (await response.json()) as RawUploadResponse
  const rawAttachments = Array.isArray(data.attachments)
    ? data.attachments
    : data.attachment
      ? [data.attachment]
      : []

  return {
    sessionId: readSessionId(data),
    attachments: rawAttachments.map((attachment) => normalizeAttachment(attachment)),
  }
}
