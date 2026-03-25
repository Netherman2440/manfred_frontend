import { useEffect, useState } from 'react'
import type { SessionDetailResponse } from '../types/session-history'
import { fetchSessionDetail } from '../lib/session-history-api'
import { ApiError } from '../lib/api-utils'
import ChatEntryFeed from './ChatEntryFeed'

const formatDateTime = (value: string) =>
  new Intl.DateTimeFormat('pl-PL', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))

const sessionStatusLabel = (status: SessionDetailResponse['status']) => {
  switch (status) {
    case 'active':
      return 'active'
    case 'completed':
      return 'completed'
    case 'running':
      return 'running'
    case 'waiting':
      return 'waiting'
    case 'failed':
      return 'failed'
    case 'cancelled':
      return 'cancelled'
    case 'pending':
      return 'pending'
    case 'archived':
      return 'archived'
    default:
      return 'unknown'
  }
}

interface SessionDetailPageProps {
  activeSessionId: string | null
  onBackToList: () => void
  onOpenChat: () => void
  sessionId: string
}

const SessionDetailPage = ({
  activeSessionId,
  onBackToList,
  onOpenChat,
  sessionId,
}: SessionDetailPageProps) => {
  const [session, setSession] = useState<SessionDetailResponse | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [reloadKey, setReloadKey] = useState(0)

  useEffect(() => {
    const abortController = new AbortController()

    const loadSessionDetail = async () => {
      setIsLoading(true)
      setError(null)

      try {
        const response = await fetchSessionDetail(sessionId, abortController.signal)
        setSession(response)
      } catch (caughtError) {
        if (caughtError instanceof DOMException && caughtError.name === 'AbortError') {
          return
        }

        setError(
          caughtError instanceof ApiError
            ? caughtError.message
            : 'Nie udalo sie pobrac szczegolow sesji.',
        )
      } finally {
        setIsLoading(false)
      }
    }

    void loadSessionDetail()

    return () => {
      abortController.abort()
    }
  }, [reloadKey, sessionId])

  return (
    <section className="chat-page">
      <section className="terminal-window terminal-window--sessions">
        <div className="panel-signature" aria-hidden="true">
          made by agentV
        </div>

        <header className="terminal-topbar">
          <button
            className="terminal-button terminal-button--ghost"
            type="button"
            onClick={onBackToList}
          >
            &lt; sessions
          </button>

          <div className="terminal-meta">
            <span className="terminal-thread">session_id={sessionId}</span>
          </div>

          {activeSessionId === sessionId ? (
            <button className="terminal-button" type="button" onClick={onOpenChat}>
              open in chat
            </button>
          ) : (
            <button className="terminal-button" type="button" onClick={onOpenChat}>
              live chat
            </button>
          )}
        </header>

        {isLoading ? <div className="history-state history-state--loading">loading session...</div> : null}

        {!isLoading && error ? (
          <div className="history-state history-state--error">
            <p>{error}</p>
            <button
              className="terminal-button"
              type="button"
              onClick={() => setReloadKey((currentValue) => currentValue + 1)}
            >
              retry
            </button>
          </div>
        ) : null}

        {!isLoading && !error && session ? (
          <section className="session-detail-panel">
            <section className="session-detail-summary">
              <div className="session-detail-summary__headline">
                <div>
                  <p className="history-panel__eyebrow">persisted transcript</p>
                  <h2 className="history-panel__title">
                    {session.summary?.trim() || `session ${session.sessionId.slice(0, 8)}`}
                  </h2>
                </div>

                <div className="session-detail-summary__badges">
                  <span className={`agent-status agent-status--${session.status}`}>
                    {sessionStatusLabel(session.status)}
                  </span>
                  {activeSessionId === session.sessionId ? (
                    <span className="agent-chip agent-chip--active">live session</span>
                  ) : null}
                </div>
              </div>

              <dl className="session-detail-summary__meta">
                <div>
                  <dt>created</dt>
                  <dd>{formatDateTime(session.createdAt)}</dd>
                </div>

                <div>
                  <dt>updated</dt>
                  <dd>{formatDateTime(session.updatedAt)}</dd>
                </div>

                <div>
                  <dt>root agent</dt>
                  <dd>{session.rootAgentId ?? 'unknown'}</dd>
                </div>

                <div>
                  <dt>entries</dt>
                  <dd>{session.entries.length}</dd>
                </div>
              </dl>
            </section>

            <ChatEntryFeed emptyLabel="no persisted entries" entries={session.entries} />
          </section>
        ) : null}
      </section>
    </section>
  )
}

export default SessionDetailPage
