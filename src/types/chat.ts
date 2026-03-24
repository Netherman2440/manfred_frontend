export type ChatRole = 'user' | 'assistant'

export type AttachmentKind = 'image' | 'document' | 'audio' | 'other'

export interface ChatAttachmentTranscription {
  status: 'not_applicable' | 'pending' | 'completed' | 'failed'
  text?: string
}

export interface ChatAttachment {
  id: string
  kind: AttachmentKind
  mimeType: string
  originalFilename: string
  workspacePath: string
  sizeBytes: number
  transcription?: ChatAttachmentTranscription
}

export interface ChatMessage {
  id: string
  entryType: 'message'
  role: 'user'
  content: string
  createdAt: string
  attachments?: ChatAttachment[]
}

export interface TextAgentItem {
  id: string
  type: 'text'
  text: string
}

export interface ReasoningAgentItem {
  id: string
  type: 'reasoning'
  text?: string
  summary?: string
  metadata?: Record<string, unknown>
}

export interface FunctionCallAgentItem {
  id: string
  type: 'function_call'
  callId: string
  name: string
  arguments: unknown
}

export interface FunctionCallOutputAgentItem {
  id: string
  type: 'function_call_output'
  callId: string
  name?: string
  output: unknown
  isError?: boolean
}

export interface UnknownAgentItem {
  id: string
  type: 'unknown'
  raw: unknown
}

export type AgentItem =
  | TextAgentItem
  | ReasoningAgentItem
  | FunctionCallAgentItem
  | FunctionCallOutputAgentItem
  | UnknownAgentItem

export interface AgentResponse {
  id: string
  entryType: 'agent_response'
  sessionId: string | null
  agentId: string
  parentAgentId?: string
  depth?: number
  agentName?: string
  role: 'assistant'
  createdAt: string
  items: AgentItem[]
}

export type ChatEntry = ChatMessage | AgentResponse

export type PendingAttachmentStatus = 'uploading' | 'ready' | 'error'

export interface PendingAttachment {
  localId: string
  kind: AttachmentKind
  mimeType: string
  originalFilename: string
  sizeBytes: number
  status: PendingAttachmentStatus
  source: 'file' | 'voice'
  attachment?: ChatAttachment
  error?: string
}
