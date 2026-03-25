import type { ChatEntry, TurnExecutionStatus } from './chat'

export type SessionHistoryStatus =
  | TurnExecutionStatus
  | 'active'
  | 'archived'
  | 'unknown'

export interface SessionListItem {
  id: string
  rootAgentId?: string
  status: SessionHistoryStatus
  summary?: string
  createdAt: string
  updatedAt: string
}

export interface SessionListResponse {
  sessions: SessionListItem[]
}

export interface SessionDetailResponse {
  sessionId: string
  rootAgentId?: string
  status: SessionHistoryStatus
  summary?: string
  createdAt: string
  updatedAt: string
  entries: ChatEntry[]
}
