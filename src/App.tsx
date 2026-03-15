import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import './App.css'
import { chatEndpointLabel, ChatApiError, sendChatMessage } from './lib/chat-api'
import {
  clearStoredChatState,
  createThreadId,
  loadStoredChatState,
  saveStoredChatState,
} from './lib/storage'
import type { ChatMessage } from './types/chat'
import MatrixRain from './components/MatrixRain'

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

const createMessage = (
  role: ChatMessage['role'],
  content: string,
): ChatMessage => ({
  id: crypto.randomUUID(),
  role,
  content,
  createdAt: new Date().toISOString(),
})

const randomGlyph = () =>
  scrambleGlyphs[Math.floor(Math.random() * scrambleGlyphs.length)]

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
  messages: ChatMessage[]
  threadId: string
  onBack: () => void
  onChangeDraft: (value: string) => void
  onResetThread: () => void
  onSend: (nextDraft?: string) => Promise<void>
  onAbort: () => void
}

const ChatPage = ({
  draft,
  error,
  isSending,
  messages,
  threadId,
  onBack,
  onChangeDraft,
  onResetThread,
  onSend,
  onAbort,
}: ChatPageProps) => {
  const feedRef = useRef<HTMLDivElement | null>(null)

  useEffect(() => {
    const feed = feedRef.current
    if (!feed) {
      return
    }

    feed.scrollTo({
      top: feed.scrollHeight,
      behavior: 'smooth',
    })
  }, [isSending, messages])

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
            <span className="terminal-thread">thread_id={threadId}</span>
          </div>

          <button className="terminal-button" type="button" onClick={onResetThread}>
            new thread
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
                {message.role === 'assistant' ? (
                  <Suspense fallback={<p className="message-plain">{message.content}</p>}>
                    <AssistantMarkdown content={message.content} />
                  </Suspense>
                ) : (
                  <p className="message-plain">{message.content}</p>
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

        <form
          className="composer"
          onSubmit={(event) => {
            event.preventDefault()
            void onSend()
          }}
        >
          <label className="sr-only" htmlFor="chat-message">
            Wiadomosc do asystenta
          </label>

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
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault()
                  void onSend()
                }
              }}
            />
          </div>

          <div className="composer-actions">
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

              <button
                className="terminal-button"
                type="submit"
                disabled={isSending || draft.trim().length === 0}
              >
                send
              </button>
            </div>
          </div>
        </form>
      </section>
    </section>
  )
}

function App() {
  const [route, setRoute] = useState<Route>(() => getCurrentRoute())
  const [initialState] = useState(() => loadStoredChatState())
  const [threadId, setThreadId] = useState(() => initialState?.threadId ?? createThreadId())
  const [messages, setMessages] = useState<ChatMessage[]>(() => initialState?.messages ?? [])
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

  useEffect(() => {
    saveStoredChatState({
      threadId,
      messages,
    })
  }, [messages, threadId])

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

  const navigate = (nextRoute: Route) => {
    if (window.location.pathname !== nextRoute) {
      window.history.pushState({}, '', nextRoute)
    }

    setRoute(nextRoute)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const handleSend = async (nextDraft?: string) => {
    const messageText = (nextDraft ?? draft).trim()

    if (!messageText || isSending) {
      return
    }

    const userMessage = createMessage('user', messageText)
    const controller = new AbortController()

    abortControllerRef.current = controller
    setError(null)
    setIsSending(true)
    setMessages((currentMessages) => [...currentMessages, userMessage])
    setDraft('')

    try {
      const response = await sendChatMessage(
        {
          message: messageText,
          threadId,
        },
        controller.signal,
      )

      setMessages((currentMessages) => [
        ...currentMessages,
        createMessage('assistant', response.message),
      ])
    } catch (caughtError) {
      if (caughtError instanceof DOMException && caughtError.name === 'AbortError') {
        return
      }

      setError(
        caughtError instanceof ChatApiError
          ? caughtError.message
          : `Blad polaczenia z ${chatEndpointLabel}.`,
      )
    } finally {
      abortControllerRef.current = null
      setIsSending(false)
    }
  }

  const handleResetThread = () => {
    abortControllerRef.current?.abort()
    clearStoredChatState()
    setThreadId(createThreadId())
    setMessages([])
    setDraft('')
    setError(null)
    setIsSending(false)
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
          messages={messages}
          threadId={threadId}
          onBack={() => navigate('/')}
          onChangeDraft={setDraft}
          onResetThread={handleResetThread}
          onSend={handleSend}
          onAbort={() => abortControllerRef.current?.abort()}
        />
      )}
    </main>
  )
}

export default App
