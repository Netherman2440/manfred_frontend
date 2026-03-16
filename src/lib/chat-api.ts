const apiBaseUrl = (import.meta.env.API_BASE_URL ?? '').replace(/\/+$/, '')

export const chatEndpointPath = '/api/v1/chat'
export const chatEndpointLabel = apiBaseUrl
  ? `${apiBaseUrl}${chatEndpointPath}`
  : chatEndpointPath

export interface ChatResponse {
  message: string
}

interface ChatPayload {
  message: string
  threadId: string
}

interface ValidationError {
  loc?: Array<number | string>
  msg?: string
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

export const sendChatMessage = async (
  payload: ChatPayload,
  signal?: AbortSignal,
): Promise<ChatResponse> => {
  const response = await fetch(chatEndpointLabel, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: payload.message,
      thread_id: payload.threadId,
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

  return (await response.json()) as ChatResponse
}
