import type { ChangeEvent, FormEvent, KeyboardEvent, RefObject } from 'react'
import AttachmentList from './AttachmentList'
import type { PendingAttachment } from '../types/chat'

const formatDuration = (durationMs: number) => {
  const totalSeconds = Math.floor(durationMs / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60

  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

interface ChatComposerProps {
  draft: string
  canSend: boolean
  isSending: boolean
  isRecording: boolean
  isRecorderSupported: boolean
  durationMs: number
  pendingAttachments: PendingAttachment[]
  fileInputRef: RefObject<HTMLInputElement | null>
  onAbort: () => void
  onAttachFiles: (event: ChangeEvent<HTMLInputElement>) => void
  onChangeDraft: (value: string) => void
  onSend: () => void
  onRemoveAttachment: (localId: string) => void
  onStartRecording: () => void
  onStopRecording: () => void
  onCancelRecording: () => void
}

const ChatComposer = ({
  draft,
  canSend,
  isSending,
  isRecording,
  isRecorderSupported,
  durationMs,
  pendingAttachments,
  fileInputRef,
  onAbort,
  onAttachFiles,
  onChangeDraft,
  onSend,
  onRemoveAttachment,
  onStartRecording,
  onStopRecording,
  onCancelRecording,
}: ChatComposerProps) => {
  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    onSend()
  }

  const handleKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      onSend()
    }
  }

  return (
    <form className="composer" onSubmit={handleSubmit}>
      <label className="sr-only" htmlFor="chat-message">
        Wiadomosc do asystenta
      </label>

      <input
        ref={fileInputRef}
        className="sr-only"
        id="chat-attachments"
        type="file"
        multiple
        onChange={onAttachFiles}
      />

      <AttachmentList
        attachments={pendingAttachments}
        disabled={isSending}
        onRemove={onRemoveAttachment}
      />

      {isRecording ? (
        <div className="recording-banner" role="status" aria-live="polite">
          <span>recording {formatDuration(durationMs)}</span>

          <div className="recording-banner__actions">
            <button className="terminal-button terminal-button--ghost" type="button" onClick={onCancelRecording}>
              cancel
            </button>
            <button className="terminal-button" type="button" onClick={onStopRecording}>
              stop
            </button>
          </div>
        </div>
      ) : null}

      <div className="composer-shell">
        <span className="composer-prompt" aria-hidden="true">
          &gt;
        </span>

        <textarea
          id="chat-message"
          className="composer-textarea"
          value={draft}
          rows={3}
          placeholder="write command..."
          onChange={(event) => onChangeDraft(event.target.value)}
          onKeyDown={handleKeyDown}
        />
      </div>

      <div className="composer-actions">
        <div className="composer-actions__buttons composer-actions__buttons--utility">
          <button
            className="terminal-button terminal-button--ghost"
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={isSending || isRecording}
          >
            attach
          </button>

          {isRecorderSupported ? (
            <button
              className="terminal-button terminal-button--ghost"
              type="button"
              onClick={onStartRecording}
              disabled={isSending || isRecording}
            >
              record
            </button>
          ) : null}
        </div>

        <div className="composer-actions__buttons">
          {isSending ? (
            <button
              className="terminal-button terminal-button--ghost"
              type="button"
              onClick={onAbort}
            >
              abort
            </button>
          ) : null}

          <button className="terminal-button" type="submit" disabled={!canSend || isSending}>
            send
          </button>
        </div>
      </div>
    </form>
  )
}

export default ChatComposer
