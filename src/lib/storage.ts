import type { ChatEntry } from '../types/chat'
import { normalizeChatEntry } from './chat-entry-normalization'

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
        .map((entry) => normalizeChatEntry(entry, parsedValue.sessionId))
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
