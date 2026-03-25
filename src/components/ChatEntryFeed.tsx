import type { RefObject } from 'react'
import type { ChatAttachment, ChatEntry } from '../types/chat'
import AgentResponseBlock from './AgentResponseBlock'

const formatTime = (value: string) =>
  new Intl.DateTimeFormat('pl-PL', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(new Date(value))

const formatAttachmentSize = (sizeBytes: number) => {
  if (sizeBytes >= 1024 * 1024) {
    return `${(sizeBytes / (1024 * 1024)).toFixed(1)} MB`
  }

  if (sizeBytes >= 1024) {
    return `${Math.round(sizeBytes / 1024)} KB`
  }

  return `${sizeBytes} B`
}

const isAgentResponse = (entry: ChatEntry) => entry.entryType === 'agent_response'

const attachmentStatusLabel = (attachment: ChatAttachment) => {
  if (attachment.kind !== 'audio' || !attachment.transcription) {
    return null
  }

  if (attachment.transcription.status === 'pending') {
    return 'transcribing'
  }

  if (attachment.transcription.status === 'failed') {
    return 'transcription failed'
  }

  return 'transcription ready'
}

const MessageAttachments = ({ attachments }: { attachments: ChatAttachment[] }) => (
  <div className="message-attachments">
    {attachments.map((attachment) => (
      <div key={attachment.id} className="message-attachment">
        <div className="message-attachment__topline">
          <span>{attachment.originalFilename}</span>
          <span>{attachment.kind}</span>
        </div>

        <div className="message-attachment__meta">
          <span>{formatAttachmentSize(attachment.sizeBytes)}</span>
          {attachmentStatusLabel(attachment) ? (
            <span>{attachmentStatusLabel(attachment)}</span>
          ) : null}
        </div>

        {attachment.kind === 'audio' && attachment.transcription?.text ? (
          <p className="message-attachment__transcription">
            {attachment.transcription.text}
          </p>
        ) : null}
      </div>
    ))}
  </div>
)

interface ChatEntryFeedProps {
  emptyLabel?: string
  entries: ChatEntry[]
  feedRef?: RefObject<HTMLDivElement | null>
  isSending?: boolean
}

const ChatEntryFeed = ({
  emptyLabel = 'no messages yet',
  entries,
  feedRef,
  isSending = false,
}: ChatEntryFeedProps) => (
  <div
    ref={feedRef}
    className={`message-feed ${entries.length === 0 ? 'message-feed--idle' : ''}`}
  >
    {entries.length === 0 ? <div className="empty-log">{emptyLabel}</div> : null}

    {entries.map((entry) => (
      <article key={entry.id} className={`message-row message-row--${entry.role}`}>
        <div className="message-prefix">
          <span>{entry.role === 'assistant' ? 'ai' : 'usr'}</span>
          <time dateTime={entry.createdAt}>{formatTime(entry.createdAt)}</time>
        </div>

        <div className="message-content">
          {isAgentResponse(entry) ? (
            <AgentResponseBlock response={entry} />
          ) : (
            <>
              {entry.content ? <p className="message-plain">{entry.content}</p> : null}

              {entry.attachments?.length ? (
                <MessageAttachments attachments={entry.attachments} />
              ) : null}
            </>
          )}
        </div>
      </article>
    ))}

    {isSending ? (
      <article className="message-row message-row--assistant">
        <div className="message-prefix">
          <span>ai</span>
          <span>stream</span>
        </div>

        <div className="message-content">
          <div className="typing-indicator" aria-label="Backend odpowiada">
            <span />
            <span />
            <span />
          </div>
        </div>
      </article>
    ) : null}
  </div>
)

export default ChatEntryFeed
