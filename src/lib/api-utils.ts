interface ValidationError {
  loc?: Array<number | string>
  msg?: string
}

interface ErrorResponsePayload {
  detail?: unknown
  message?: unknown
}

export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

export const apiBaseUrl = (import.meta.env.API_BASE_URL ?? '').replace(/\/+$/, '')

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

export const readErrorResponse = async (response: Response) => {
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
