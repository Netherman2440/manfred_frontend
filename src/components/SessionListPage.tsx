import { useEffect, useState } from 'react'
import type { SessionListItem } from '../types/session-history'
import { fetchSessionList } from '../lib/session-history-api'
import { ApiError } from '../lib/api-utils'

const formatDateTime = (value: string) =>
  new Intl.DateTimeFormat('pl-PL', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))

const sessionStatusLabel = (status: SessionListItem['status']) => {
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

const sessionSummary = (session: SessionListItem) =>
  session.summary?.trim() || `session ${session.id.slice(0, 8)}`

interface SessionListPageProps {
  activeSessionId: string | null
  onBack: () => void
  onOpenChat: () => void
  onOpenSession: (sessionId: string) => void
}

const SessionListPage = ({
  activeSessionId,
  onBack,
  onOpenChat,
  onOpenSession,
}: SessionListPageProps) => {
  const [sessions, setSessions] = useState<SessionListItem[]>([])
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [reloadKey, setReloadKey] = useState(0)

  useEffect(() => {
    const abortController = new AbortController()

    const loadSessions = async () => {
      setIsLoading(true)
      setError(null)

      try {
        const response = await fetchSessionList(abortController.signal)
        setSessions(response.sessions)
      } catch (caughtError) {
        if (caughtError instanceof DOMException && caughtError.name === 'AbortError') {
          return
        }

        setError(
          caughtError instanceof ApiError
            ? caughtError.message
            : 'Nie udalo sie pobrac listy sesji.',
        )
      } finally {
        setIsLoading(false)
      }
    }

    void loadSessions()

    return () => {
      abortController.abort()
    }
  }, [reloadKey])

  return (
    <section className="chat-page">
      <section className="terminal-window terminal-window--sessions">
        <div className="panel-signature" aria-hidden="true">
          made by agentV
        </div>

        <header className="terminal-topbar">
          <button className="terminal-button terminal-button--ghost" type="button" onClick={onBack}>
            &lt; root
          </button>

          <div className="terminal-meta">
            <span className="terminal-thread">session history</span>
          </div>

          <button className="terminal-button" type="button" onClick={onOpenChat}>
            live chat
          </button>
        </header>

        <section className="history-panel">
          <header className="history-panel__header">
            <div>
              <p className="history-panel__eyebrow">archive index</p>
              <h2 className="history-panel__title">sessions</h2>
            </div>

            <button
              className="terminal-button terminal-button--ghost"
              type="button"
              onClick={() => setReloadKey((currentValue) => currentValue + 1)}
            >
              refresh
            </button>
          </header>

          {isLoading ? (
            <div className="history-state history-state--loading">loading sessions...</div>
          ) : null}

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

          {!isLoading && !error && sessions.length === 0 ? (
            <div className="history-state">no persisted sessions yet</div>
          ) : null}

          {!isLoading && !error && sessions.length > 0 ? (
            <div className="session-list" role="list">
              {sessions.map((session) => {
                const isActiveSession = activeSessionId === session.id

                return (
                  <article key={session.id} className="session-card" role="listitem">
                    <div className="session-card__header">
                      <div className="session-card__title-row">
                        <h3>{sessionSummary(session)}</h3>
                        <span className={`agent-status agent-status--${session.status}`}>
                          {sessionStatusLabel(session.status)}
                        </span>
                        {isActiveSession ? (
                          <span className="agent-chip agent-chip--active">live</span>
                        ) : null}
                      </div>

                      <p className="session-card__id">session_id={session.id}</p>
                    </div>

                    <dl className="session-card__meta">
                      <div>
                        <dt>updated</dt>
                        <dd>{formatDateTime(session.updatedAt)}</dd>
                      </div>

                      <div>
                        <dt>created</dt>
                        <dd>{formatDateTime(session.createdAt)}</dd>
                      </div>

                      <div>
                        <dt>root agent</dt>
                        <dd>{session.rootAgentId ?? 'unknown'}</dd>
                      </div>
                    </dl>

                    <div className="session-card__actions">
                      <button
                        className="terminal-button"
                        type="button"
                        onClick={() => onOpenSession(session.id)}
                      >
                        open details
                      </button>
                    </div>
                  </article>
                )
              })}
            </div>
          ) : null}
        </section>
      </section>
    </section>
  )
}

export default SessionListPage
