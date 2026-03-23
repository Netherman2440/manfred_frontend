import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import './App.css'
import {
  ChatApiError,
  chatAttachmentsEndpointLabel,
  chatCompletionsEndpointLabel,
  sendChatCompletion,
  uploadAttachments,
} from './lib/chat-api'
import {
  clearStoredChatState,
  loadStoredChatState,
  saveStoredChatState,
} from './lib/storage'
import type { ChatAttachment, ChatMessage, PendingAttachment } from './types/chat'
import MatrixRain from './components/MatrixRain'
import ChatComposer from './components/ChatComposer'
import { useVoiceRecorder } from './hooks/useVoiceRecorder'

const AssistantMarkdown = lazy(() => import('./components/AssistantMarkdown'))

const targetWord = ['M', 'A', 'N', 'F', 'R', 'E', 'D']
const routeChat = '/chat'
const scrambleGlyphs = '01ABCDEFGHIJKLMNOPQRSTUVWXYZ#$%&*+-<>'
const matrixRainStorageKey = 'manfred-matrix-rain-enabled'

type Route = '/' | '/chat'

const getCurrentRoute = (): Route =>
  window.location.pathname === routeChat ? routeChat : '/'

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

const inferAttachmentKind = (mimeType: string) => {
  if (mimeType.startsWith('image/')) {
    return 'image'
  }

  if (mimeType.startsWith('audio/')) {
    return 'audio'
  }

  if (
    mimeType === 'application/pdf' ||
    mimeType.startsWith('text/') ||
    mimeType.includes('document') ||
    mimeType.includes('sheet') ||
    mimeType.includes('presentation')
  ) {
    return 'document'
  }

  return 'other'
}

const createMessage = (
  role: ChatMessage['role'],
  content: string,
  attachments?: ChatAttachment[],
): ChatMessage => ({
  id: crypto.randomUUID(),
  role,
  content,
  createdAt: new Date().toISOString(),
  attachments: attachments && attachments.length > 0 ? attachments : undefined,
})

const randomGlyph = () =>
  scrambleGlyphs[Math.floor(Math.random() * scrambleGlyphs.length)]

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

const LandingWord = () => {
  const [characters, setCharacters] = useState(() =>
    targetWord.map(() => randomGlyph()),
  )

  useEffect(() => {
    const startedAt = performance.now()
    const stopTimes = [320, 520, 760, 1000, 1260, 1540, 1840]
    const intervalId = window.setInterval(() => {
      const elapsed = performance.now() - startedAt

      setCharacters(
        targetWord.map((character, index) =>
          elapsed >= stopTimes[index] ? character : randomGlyph(),
        ),
      )

      if (elapsed >= 1900) {
        window.clearInterval(intervalId)
        setCharacters(targetWord)
      }
    }, 48)

    return () => {
      window.clearInterval(intervalId)
    }
  }, [])

  return (
    <h1 className="landing-title" aria-label="MANFRED">
      {characters.map((character, index) => (
        <span key={`${character}-${index}`}>{character}</span>
      ))}
    </h1>
  )
}

interface LandingPageProps {
  onEnter: () => void
}

const LandingPage = ({ onEnter }: LandingPageProps) => (
  <section className="landing-page">
    <div className="landing-panel">
      <div className="panel-signature" aria-hidden="true">
        made by agentV
      </div>
      <p className="landing-kicker">system_boot_sequence</p>
      <LandingWord />
      <button className="terminal-button landing-button" type="button" onClick={onEnter}>
        hello_world&gt;
      </button>
    </div>
  </section>
)

interface ChatPageProps {
  draft: string
  error: string | null
  isSending: boolean
  isRecording: boolean
  isRecorderSupported: boolean
  recorderDurationMs: number
  messages: ChatMessage[]
  pendingAttachments: PendingAttachment[]
  sessionId: string | null
  onBack: () => void
  onChangeDraft: (value: string) => void
  onAttachFiles: (files: FileList | null) => void
  onRemoveAttachment: (localId: string) => void
  onResetSession: () => void
  onSend: () => Promise<void>
  onAbort: () => void
  onStartRecording: () => Promise<void>
  onStopRecording: () => Promise<void>
  onCancelRecording: () => Promise<void>
}

const ChatPage = ({
  draft,
  error,
  isSending,
  isRecording,
  isRecorderSupported,
  recorderDurationMs,
  messages,
  pendingAttachments,
  sessionId,
  onBack,
  onChangeDraft,
  onAttachFiles,
  onRemoveAttachment,
  onResetSession,
  onSend,
  onAbort,
  onStartRecording,
  onStopRecording,
  onCancelRecording,
}: ChatPageProps) => {
  const feedRef = useRef<HTMLDivElement | null>(null)
  const fileInputRef = useRef<HTMLInputElement | null>(null)

  useEffect(() => {
    const feed = feedRef.current
    if (!feed) {
      return
    }

    feed.scrollTo({
      top: feed.scrollHeight,
      behavior: 'smooth',
    })
  }, [isSending, isRecording, messages, pendingAttachments])

  const canSend =
    !isSending &&
    !isRecording &&
    pendingAttachments.every((attachment) => attachment.status !== 'uploading') &&
    (draft.trim().length > 0 ||
      pendingAttachments.some((attachment) => attachment.status === 'ready'))

  return (
    <section className="chat-page">
      <section className="terminal-window">
        <div className="panel-signature" aria-hidden="true">
          made by agentV
        </div>
        <header className="terminal-topbar">
          <button className="terminal-button terminal-button--ghost" type="button" onClick={onBack}>
            &lt; root
          </button>

          <div className="terminal-meta">
            <span className="terminal-thread">
              session_id={sessionId ?? 'pending'}
            </span>
          </div>

          <button className="terminal-button" type="button" onClick={onResetSession}>
            new session
          </button>
        </header>

        {error ? (
          <div className="terminal-error">
            <span>error:</span> {error}
          </div>
        ) : null}

        <div
          ref={feedRef}
          className={`message-feed ${messages.length === 0 ? 'message-feed--idle' : ''}`}
        >
          {messages.length === 0 ? (
            <div className="empty-log">no messages yet</div>
          ) : null}

          {messages.map((message) => (
            <article
              key={message.id}
              className={`message-row message-row--${message.role}`}
            >
              <div className="message-prefix">
                <span>{message.role === 'assistant' ? 'ai' : 'usr'}</span>
                <time dateTime={message.createdAt}>{formatTime(message.createdAt)}</time>
              </div>

              <div className="message-content">
                {message.content ? (
                  message.role === 'assistant' ? (
                    <Suspense fallback={<p className="message-plain">{message.content}</p>}>
                      <AssistantMarkdown content={message.content} />
                    </Suspense>
                  ) : (
                    <p className="message-plain">{message.content}</p>
                  )
                ) : null}

                {message.attachments?.length ? (
                  <MessageAttachments attachments={message.attachments} />
                ) : null}
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

        <ChatComposer
          draft={draft}
          canSend={canSend}
          isSending={isSending}
          isRecording={isRecording}
          isRecorderSupported={isRecorderSupported}
          durationMs={recorderDurationMs}
          pendingAttachments={pendingAttachments}
          fileInputRef={fileInputRef}
          onAbort={onAbort}
          onAttachFiles={(event) => {
            onAttachFiles(event.target.files)
            event.target.value = ''
          }}
          onChangeDraft={onChangeDraft}
          onSend={() => {
            if (canSend) {
              void onSend()
            }
          }}
          onRemoveAttachment={onRemoveAttachment}
          onStartRecording={() => {
            void onStartRecording()
          }}
          onStopRecording={() => {
            void onStopRecording()
          }}
          onCancelRecording={() => {
            void onCancelRecording()
          }}
        />
      </section>
    </section>
  )
}

function App() {
  const [route, setRoute] = useState<Route>(() => getCurrentRoute())
  const [initialState] = useState(() => loadStoredChatState())
  const [sessionId, setSessionId] = useState<string | null>(() => initialState?.sessionId ?? null)
  const [messages, setMessages] = useState<ChatMessage[]>(() => initialState?.messages ?? [])
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([])
  const [draft, setDraft] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isSending, setIsSending] = useState(false)
  const [isRainEnabled, setIsRainEnabled] = useState(() => {
    if (typeof window === 'undefined') {
      return true
    }

    return window.localStorage.getItem(matrixRainStorageKey) !== 'false'
  })
  const abortControllerRef = useRef<AbortController | null>(null)
  const sessionIdRef = useRef<string | null>(sessionId)
  const generationRef = useRef(0)
  const uploadQueueRef = useRef<Promise<void>>(Promise.resolve())
  const {
    cancelRecording,
    durationMs: recorderDurationMs,
    error: recorderError,
    isRecording,
    isSupported: isRecorderSupported,
    startRecording,
    stopRecording,
  } = useVoiceRecorder()

  useEffect(() => {
    sessionIdRef.current = sessionId
  }, [sessionId])

  useEffect(() => {
    saveStoredChatState({
      sessionId,
      messages,
    })
  }, [messages, sessionId])

  useEffect(() => {
    const handlePopState = () => {
      setRoute(getCurrentRoute())
    }

    window.addEventListener('popstate', handlePopState)

    return () => {
      window.removeEventListener('popstate', handlePopState)
    }
  }, [])

  useEffect(
    () => () => {
      abortControllerRef.current?.abort()
    },
    [],
  )

  useEffect(() => {
    window.localStorage.setItem(matrixRainStorageKey, String(isRainEnabled))
  }, [isRainEnabled])

  useEffect(() => {
    if (recorderError) {
      setError(recorderError)
    }
  }, [recorderError])

  const navigate = (nextRoute: Route) => {
    if (window.location.pathname !== nextRoute) {
      window.history.pushState({}, '', nextRoute)
    }

    setRoute(nextRoute)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const queueAttachmentUpload = (file: File, source: PendingAttachment['source']) => {
    const localId = crypto.randomUUID()
    const generation = generationRef.current

    setPendingAttachments((currentAttachments) => [
      ...currentAttachments,
      {
        localId,
        kind: inferAttachmentKind(file.type),
        mimeType: file.type || 'application/octet-stream',
        originalFilename: file.name,
        sizeBytes: file.size,
        status: 'uploading',
        source,
      },
    ])

    uploadQueueRef.current = uploadQueueRef.current
      .catch(() => undefined)
      .then(async () => {
        try {
          const response = await uploadAttachments({
            files: [file],
            sessionId: sessionIdRef.current,
          })

          if (generation !== generationRef.current) {
            return
          }

          if (response.sessionId) {
            sessionIdRef.current = response.sessionId
            setSessionId(response.sessionId)
          }

          const uploadedAttachment = response.attachments[0]

          if (!uploadedAttachment) {
            throw new ChatApiError('Backend nie zwrocil attachmentu po uploadzie.', 500)
          }

          setPendingAttachments((currentAttachments) =>
            currentAttachments.map((attachment) =>
              attachment.localId === localId
                ? {
                    ...attachment,
                    status: 'ready',
                    attachment: uploadedAttachment,
                    kind: uploadedAttachment.kind,
                    mimeType: uploadedAttachment.mimeType,
                    originalFilename: uploadedAttachment.originalFilename,
                    sizeBytes: uploadedAttachment.sizeBytes,
                    error: undefined,
                  }
                : attachment,
            ),
          )
        } catch (caughtError) {
          if (generation !== generationRef.current) {
            return
          }

          setPendingAttachments((currentAttachments) =>
            currentAttachments.map((attachment) =>
              attachment.localId === localId
                ? {
                    ...attachment,
                    status: 'error',
                    error:
                      caughtError instanceof ChatApiError
                        ? caughtError.message
                        : `Blad polaczenia z ${chatAttachmentsEndpointLabel}.`,
                  }
                : attachment,
            ),
          )
        }
      })
  }

  const handleAttachFiles = (files: FileList | null) => {
    if (!files || files.length === 0) {
      return
    }

    setError(null)
    Array.from(files).forEach((file) => {
      queueAttachmentUpload(file, 'file')
    })
  }

  const handleSend = async () => {
    const messageText = draft.trim()
    const readyAttachments = pendingAttachments
      .filter((attachment): attachment is PendingAttachment & { attachment: ChatAttachment } => {
        return attachment.status === 'ready' && Boolean(attachment.attachment)
      })
      .map((attachment) => attachment.attachment)

    if (
      isSending ||
      isRecording ||
      pendingAttachments.some((attachment) => attachment.status === 'uploading') ||
      (messageText.length === 0 && readyAttachments.length === 0)
    ) {
      return
    }

    const userMessage = createMessage('user', messageText, readyAttachments)
    const controller = new AbortController()

    abortControllerRef.current = controller
    setError(null)
    setIsSending(true)
    setMessages((currentMessages) => [...currentMessages, userMessage])
    setDraft('')

    try {
      const response = await sendChatCompletion(
        {
          sessionId,
          message: messageText || undefined,
          attachmentIds: readyAttachments.map((attachment) => attachment.id),
        },
        controller.signal,
      )

      if (response.sessionId) {
        sessionIdRef.current = response.sessionId
        setSessionId(response.sessionId)
      }

      setPendingAttachments([])

      if (response.message) {
        setMessages((currentMessages) => [
          ...currentMessages,
          createMessage('assistant', response.message),
        ])
      }
    } catch (caughtError) {
      if (caughtError instanceof DOMException && caughtError.name === 'AbortError') {
        setMessages((currentMessages) =>
          currentMessages.filter((message) => message.id !== userMessage.id),
        )
        setDraft(messageText)
        return
      }

      setMessages((currentMessages) =>
        currentMessages.filter((message) => message.id !== userMessage.id),
      )
      setDraft(messageText)
      setError(
        caughtError instanceof ChatApiError
          ? caughtError.message
          : `Blad polaczenia z ${chatCompletionsEndpointLabel}.`,
      )
    } finally {
      abortControllerRef.current = null
      setIsSending(false)
    }
  }

  const handleResetSession = () => {
    generationRef.current += 1
    abortControllerRef.current?.abort()
    clearStoredChatState()
    sessionIdRef.current = null
    uploadQueueRef.current = Promise.resolve()
    setSessionId(null)
    setMessages([])
    setPendingAttachments([])
    setDraft('')
    setError(null)
    setIsSending(false)
    void cancelRecording()
  }

  const handleStopRecording = async () => {
    let recordedAudio = null

    try {
      recordedAudio = await stopRecording()
    } catch (caughtError) {
      setError(
        caughtError instanceof Error ? caughtError.message : 'Nagrywanie nie powiodlo sie.',
      )
      return
    }

    if (!recordedAudio) {
      return
    }

    const timestamp = new Date().toISOString().replaceAll(':', '-')
    const file = new File(
      [recordedAudio.blob],
      `voice-${timestamp}.${recordedAudio.extension}`,
      {
        type: recordedAudio.mimeType,
        lastModified: Date.now(),
      },
    )

    setError(null)
    queueAttachmentUpload(file, 'voice')
  }

  return (
    <main className="app-shell">
      <button
        className="terminal-button rain-toggle"
        type="button"
        aria-pressed={isRainEnabled}
        onClick={() => setIsRainEnabled((currentValue) => !currentValue)}
      >
        rain: {isRainEnabled ? 'on' : 'off'}
      </button>

      {isRainEnabled ? <MatrixRain /> : null}

      {route === '/' ? (
        <LandingPage onEnter={() => navigate(routeChat)} />
      ) : (
        <ChatPage
          draft={draft}
          error={error}
          isSending={isSending}
          isRecording={isRecording}
          isRecorderSupported={isRecorderSupported}
          recorderDurationMs={recorderDurationMs}
          messages={messages}
          pendingAttachments={pendingAttachments}
          sessionId={sessionId}
          onBack={() => navigate('/')}
          onChangeDraft={setDraft}
          onAttachFiles={handleAttachFiles}
          onRemoveAttachment={(localId) => {
            setPendingAttachments((currentAttachments) =>
              currentAttachments.filter((attachment) => attachment.localId !== localId),
            )
          }}
          onResetSession={handleResetSession}
          onSend={handleSend}
          onAbort={() => abortControllerRef.current?.abort()}
          onStartRecording={startRecording}
          onStopRecording={handleStopRecording}
          onCancelRecording={cancelRecording}
        />
      )}
    </main>
  )
}

export default App
