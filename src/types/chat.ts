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

export type AgentExecutionStatus =
  | 'pending'
  | 'running'
  | 'waiting'
  | 'completed'
  | 'failed'
  | 'cancelled'

export type TurnExecutionStatus = AgentExecutionStatus

export interface WaitingForState {
  id: string
  label: string
  kind?: string
  raw: unknown
}

export interface ToolTraceGroup {
  callId: string
  toolName: string
  callItem?: FunctionCallAgentItem
  resultItem?: FunctionCallOutputAgentItem
  childAgents: AgentTreeNode[]
}

export type AgentTimelineItem =
  | {
      id: string
      type: 'text'
      item: TextAgentItem
    }
  | {
      id: string
      type: 'reasoning'
      item: ReasoningAgentItem
    }
  | {
      id: string
      type: 'tool'
      group: ToolTraceGroup
    }
  | {
      id: string
      type: 'unknown'
      item: UnknownAgentItem
    }

export interface AgentTreeNode {
  agentId: string
  agentName: string
  status: AgentExecutionStatus
  depth: number
  parentAgentId?: string
  sourceCallId?: string
  waitingFor?: WaitingForState[]
  timeline: AgentTimelineItem[]
  childAgents: AgentTreeNode[]
  isActive: boolean
}

export interface AgentResponse {
  id: string
  entryType: 'agent_response'
  sessionId: string | null
  rootAgentId: string
  activeAgentId?: string
  turnStatus: TurnExecutionStatus
  role: 'assistant'
  createdAt: string
  agents: AgentTreeNode[]
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
