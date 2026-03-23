export type ChatRole = 'user' | 'assistant'

export type AttachmentKind = 'image' | 'document' | 'audio' | 'other'

export interface ChatAttachmentTranscription {
  status: 'pending' | 'completed' | 'failed'
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
  role: ChatRole
  content: string
  createdAt: string
  attachments?: ChatAttachment[]
}

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
