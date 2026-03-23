import type { PendingAttachment } from '../types/chat'

interface AttachmentListProps {
  attachments: PendingAttachment[]
  disabled?: boolean
  onRemove: (localId: string) => void
}

const formatSize = (sizeBytes: number) => {
  if (sizeBytes >= 1024 * 1024) {
    return `${(sizeBytes / (1024 * 1024)).toFixed(1)} MB`
  }

  if (sizeBytes >= 1024) {
    return `${Math.round(sizeBytes / 1024)} KB`
  }

  return `${sizeBytes} B`
}

const describeStatus = (attachment: PendingAttachment) => {
  if (attachment.status === 'uploading') {
    return 'uploading'
  }

  if (attachment.status === 'error') {
    return attachment.error ?? 'upload failed'
  }

  if (attachment.kind === 'audio' && attachment.attachment?.transcription?.status) {
    if (attachment.attachment.transcription.status === 'completed') {
      return attachment.attachment.transcription.text
        ? 'transcription ready'
        : 'transcription completed'
    }

    if (attachment.attachment.transcription.status === 'pending') {
      return 'transcribing'
    }

    return 'transcription failed'
  }

  return 'ready'
}

const attachmentClassName = (attachment: PendingAttachment) =>
  `attachment-chip attachment-chip--${attachment.status}`

const AttachmentList = ({ attachments, disabled = false, onRemove }: AttachmentListProps) => {
  if (attachments.length === 0) {
    return null
  }

  return (
    <div className="attachment-list" aria-label="Zalaczniki gotowe do wyslania">
      {attachments.map((attachment) => (
        <div key={attachment.localId} className={attachmentClassName(attachment)}>
          <div className="attachment-chip__body">
            <div className="attachment-chip__title">
              <span>{attachment.originalFilename}</span>
              <span>{formatSize(attachment.sizeBytes)}</span>
            </div>

            <div className="attachment-chip__meta">
              <span>{attachment.kind}</span>
              <span>{describeStatus(attachment)}</span>
            </div>
          </div>

          <button
            className="attachment-chip__remove"
            type="button"
            onClick={() => onRemove(attachment.localId)}
            disabled={disabled}
            aria-label={`Usun ${attachment.originalFilename}`}
          >
            x
          </button>
        </div>
      ))}
    </div>
  )
}

export default AttachmentList
