import { useRef, useState } from 'react'
import type {
  ChangeEvent,
  ClipboardEvent,
  DragEvent,
  FormEvent,
  KeyboardEvent,
  RefObject,
} from 'react'
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
  onAttachFiles: (files: Iterable<File> | null) => void
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
  const [isDragActive, setIsDragActive] = useState(false)
  const dragDepthRef = useRef(0)

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    onSend()
  }

  const isFileTransfer = (dataTransfer: DataTransfer | null) =>
    Array.from(dataTransfer?.types ?? []).includes('Files')

  const handleKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      onSend()
    }
  }

  const handlePaste = (event: ClipboardEvent<HTMLTextAreaElement>) => {
    if (isSending || isRecording) {
      return
    }

    const clipboardFiles =
      event.clipboardData.files.length > 0
        ? Array.from(event.clipboardData.files)
        : Array.from(event.clipboardData.items)
            .filter((item) => item.kind === 'file')
            .map((item) => item.getAsFile())
            .filter((file): file is File => file !== null)

    if (clipboardFiles.length === 0) {
      return
    }

    event.preventDefault()
    onAttachFiles(clipboardFiles)
  }

  const handleFileInputChange = (event: ChangeEvent<HTMLInputElement>) => {
    onAttachFiles(event.target.files)
    event.target.value = ''
  }

  const handleDragEnter = (event: DragEvent<HTMLDivElement>) => {
    if (isSending || isRecording || !isFileTransfer(event.dataTransfer)) {
      return
    }

    event.preventDefault()
    dragDepthRef.current += 1
    setIsDragActive(true)
  }

  const handleDragOver = (event: DragEvent<HTMLDivElement>) => {
    if (isSending || isRecording || !isFileTransfer(event.dataTransfer)) {
      return
    }

    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
  }

  const handleDragLeave = (event: DragEvent<HTMLDivElement>) => {
    if (!isFileTransfer(event.dataTransfer)) {
      return
    }

    event.preventDefault()
    dragDepthRef.current = Math.max(0, dragDepthRef.current - 1)

    if (dragDepthRef.current === 0) {
      setIsDragActive(false)
    }
  }

  const handleDrop = (event: DragEvent<HTMLDivElement>) => {
    if (!isFileTransfer(event.dataTransfer)) {
      return
    }

    event.preventDefault()
    dragDepthRef.current = 0
    setIsDragActive(false)

    if (isSending || isRecording) {
      return
    }

    onAttachFiles(Array.from(event.dataTransfer.files))
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
        onChange={handleFileInputChange}
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

      <div
        className={`composer-shell ${isDragActive ? 'composer-shell--drag-active' : ''}`}
        onDragEnter={handleDragEnter}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
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
          onPaste={handlePaste}
        />
      </div>

      <p className="composer-drop-hint">paste files from clipboard or drop them into the message box</p>

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
