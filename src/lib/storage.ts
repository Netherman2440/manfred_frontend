import type { ChatMessage } from '../types/chat'

const storageKey = 'manfred-chat-state'

interface StoredChatState {
  sessionId: string | null
  messages: ChatMessage[]
}

export const loadStoredChatState = (): StoredChatState | null => {
  try {
    const rawValue = window.localStorage.getItem(storageKey)

    if (!rawValue) {
      return null
    }

    const parsedValue = JSON.parse(rawValue) as StoredChatState

    if (
      !('sessionId' in parsedValue) ||
      (parsedValue.sessionId !== null && typeof parsedValue.sessionId !== 'string') ||
      !Array.isArray(parsedValue.messages)
    ) {
      return null
    }

    return parsedValue
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
