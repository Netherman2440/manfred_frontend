import { ApiError, apiBaseUrl, readErrorResponse } from './api-utils'
import { normalizeChatEntry } from './chat-entry-normalization'
import type {
  SessionDetailResponse,
  SessionHistoryStatus,
  SessionListItem,
  SessionListResponse,
} from '../types/session-history'

const sessionsEndpointPath = '/api/v1/chat/sessions'
const sessionsEndpointLabel = apiBaseUrl
  ? `${apiBaseUrl}${sessionsEndpointPath}`
  : sessionsEndpointPath

const isSessionApiDebugEnabled =
  import.meta.env.DEV || import.meta.env.VITE_CHAT_API_DEBUG === 'true'

const debugSessionApi = (event: string, payload: unknown) => {
  if (!isSessionApiDebugEnabled) {
    return
  }

  console.debug(`[session-history-api] ${event}`, payload)
}

const errorSessionApi = (event: string, payload: unknown) => {
  console.error(`[session-history-api] ${event}`, payload)
}

const readOptionalString = (value: unknown) =>
  typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined

const readRequiredDate = (value: unknown, field: string) => {
  if (typeof value !== 'string') {
    throw new ApiError(`Backend zwrocil nieprawidlowe pole ${field} w historii sesji.`, 500)
  }

  const parsedDate = new Date(value)

  if (Number.isNaN(parsedDate.getTime())) {
    throw new ApiError(`Backend zwrocil nieprawidlowa date ${field} w historii sesji.`, 500)
  }

  return parsedDate.toISOString()
}

const readSessionId = (value: Record<string, unknown>) => {
  const sessionId = value.id ?? value.sessionId ?? value.session_id

  return typeof sessionId === 'string' && sessionId.length > 0 ? sessionId : null
}

const normalizeSessionStatus = (value: unknown): SessionHistoryStatus => {
  switch (value) {
    case 'pending':
    case 'running':
    case 'waiting':
    case 'completed':
    case 'failed':
    case 'cancelled':
    case 'active':
    case 'archived':
      return value
    default:
      return 'unknown'
  }
}

const normalizeSessionListItem = (value: unknown): SessionListItem => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new ApiError('Backend zwrocil nieprawidlowe dane listy sesji.', 500)
  }

  const rawValue = value as Record<string, unknown>
  const id = readSessionId(rawValue)

  if (!id) {
    throw new ApiError('Backend zwrocil sesje bez identyfikatora.', 500)
  }

  const createdAt = readRequiredDate(rawValue.createdAt ?? rawValue.created_at, 'createdAt')
  const updatedAt = readRequiredDate(
    rawValue.updatedAt ?? rawValue.updated_at ?? rawValue.createdAt ?? rawValue.created_at,
    'updatedAt',
  )

  return {
    id,
    rootAgentId: readOptionalString(rawValue.rootAgentId ?? rawValue.root_agent_id),
    status: normalizeSessionStatus(rawValue.status),
    summary: readOptionalString(rawValue.summary),
    createdAt,
    updatedAt,
  }
}

const normalizeSessionListResponse = (payload: unknown): SessionListResponse => {
  const rawSessions = Array.isArray(payload)
    ? payload
    : payload && typeof payload === 'object' && Array.isArray((payload as { sessions?: unknown }).sessions)
      ? (payload as { sessions: unknown[] }).sessions
      : null

  if (!rawSessions) {
    throw new ApiError('Backend zwrocil nieprawidlowy payload listy sesji.', 500)
  }

  return {
    sessions: rawSessions.map((session) => normalizeSessionListItem(session)),
  }
}

const normalizeSessionDetailResponse = (payload: unknown): SessionDetailResponse => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new ApiError('Backend zwrocil nieprawidlowe dane szczegolow sesji.', 500)
  }

  const rawPayload = payload as Record<string, unknown>
  const sessionId = readSessionId(rawPayload)

  if (!sessionId) {
    throw new ApiError('Backend zwrocil szczegoly sesji bez identyfikatora.', 500)
  }

  if (!Array.isArray(rawPayload.entries)) {
    throw new ApiError('Backend zwrocil nieprawidlowy feed historii sesji.', 500)
  }

  return {
    sessionId,
    rootAgentId: readOptionalString(rawPayload.rootAgentId ?? rawPayload.root_agent_id),
    status: normalizeSessionStatus(rawPayload.status),
    summary: readOptionalString(rawPayload.summary),
    createdAt: readRequiredDate(rawPayload.createdAt ?? rawPayload.created_at, 'createdAt'),
    updatedAt: readRequiredDate(
      rawPayload.updatedAt ?? rawPayload.updated_at ?? rawPayload.createdAt ?? rawPayload.created_at,
      'updatedAt',
    ),
    entries: rawPayload.entries
      .map((entry) => normalizeChatEntry(entry, sessionId))
      .filter((entry): entry is SessionDetailResponse['entries'][number] => entry !== null),
  }
}

export const fetchSessionList = async (signal?: AbortSignal): Promise<SessionListResponse> => {
  debugSessionApi('sessions.list.request', {
    url: sessionsEndpointLabel,
  })

  const response = await fetch(sessionsEndpointLabel, {
    method: 'GET',
    signal,
  })

  if (!response.ok) {
    const { message, rawBody, parsedBody } = await readErrorResponse(response)

    errorSessionApi('sessions.list.error', {
      url: sessionsEndpointLabel,
      status: response.status,
      statusText: response.statusText,
      responseBody: parsedBody ?? rawBody,
    })

    throw new ApiError(
      message ?? `Backend historii sesji zwrocil blad HTTP ${response.status}.`,
      response.status,
    )
  }

  const normalizedResponse = normalizeSessionListResponse(await response.json())

  debugSessionApi('sessions.list.response', {
    url: sessionsEndpointLabel,
    status: response.status,
    sessionCount: normalizedResponse.sessions.length,
  })

  return normalizedResponse
}

export const fetchSessionDetail = async (
  sessionId: string,
  signal?: AbortSignal,
): Promise<SessionDetailResponse> => {
  const sessionDetailEndpointLabel = `${sessionsEndpointLabel}/${encodeURIComponent(sessionId)}`

  debugSessionApi('sessions.detail.request', {
    url: sessionDetailEndpointLabel,
    sessionId,
  })

  const response = await fetch(sessionDetailEndpointLabel, {
    method: 'GET',
    signal,
  })

  if (!response.ok) {
    const { message, rawBody, parsedBody } = await readErrorResponse(response)

    errorSessionApi('sessions.detail.error', {
      url: sessionDetailEndpointLabel,
      sessionId,
      status: response.status,
      statusText: response.statusText,
      responseBody: parsedBody ?? rawBody,
    })

    throw new ApiError(
      message ?? `Backend szczegolow sesji zwrocil blad HTTP ${response.status}.`,
      response.status,
    )
  }

  const normalizedResponse = normalizeSessionDetailResponse(await response.json())

  debugSessionApi('sessions.detail.response', {
    url: sessionDetailEndpointLabel,
    sessionId,
    status: response.status,
    entryCount: normalizedResponse.entries.length,
  })

  return normalizedResponse
}
