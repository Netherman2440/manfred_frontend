import { lazy, Suspense } from 'react'
import type {
  AgentResponse,
  AgentTimelineItem,
  AgentTreeNode,
  ToolTraceGroup,
} from '../types/chat'
import ReasoningBlock from './ReasoningBlock'
import StructuredDataBlock from './StructuredDataBlock'

const AssistantMarkdown = lazy(() => import('./AssistantMarkdown'))

interface AgentResponseBlockProps {
  response: AgentResponse
}

const statusLabelMap = {
  pending: 'pending',
  running: 'running',
  waiting: 'waiting',
  completed: 'completed',
  failed: 'failed',
  cancelled: 'cancelled',
} as const

const getStatusLabel = (status: keyof typeof statusLabelMap) => statusLabelMap[status]

const renderMarkdown = (content: string) => (
  <Suspense fallback={<p className="message-plain">{content}</p>}>
    <AssistantMarkdown content={content} />
  </Suspense>
)

const WaitingForList = ({ agent }: { agent: AgentTreeNode }) => {
  if (!agent.waitingFor?.length) {
    return null
  }

  return (
    <div className="agent-section__waiting">
      <span className="agent-section__meta-label">waiting for</span>
      <div className="agent-section__waiting-list">
        {agent.waitingFor.map((entry) => (
          <span key={entry.id} className="agent-chip">
            {entry.kind ? `${entry.kind}: ${entry.label}` : entry.label}
          </span>
        ))}
      </div>
    </div>
  )
}

const ToolTraceGroupCard = ({ group }: { group: ToolTraceGroup }) => {
  const resultState = group.resultItem
    ? group.resultItem.isError
      ? 'error'
      : 'completed'
    : 'pending'

  return (
    <section
      className={`agent-item agent-tool-group agent-tool-group--${resultState}`}
    >
      <header className="agent-tool-group__header">
        <div className="agent-tool-group__title">
          <span className="agent-item__label">tool</span>
          <span className="agent-item__title">{group.toolName}</span>
        </div>

        <div className="agent-tool-group__meta">
          <span className={`agent-status agent-status--${resultState}`}>
            {resultState === 'error'
              ? 'error'
              : resultState === 'completed'
                ? 'done'
                : 'pending'}
          </span>
          <span className="agent-item__meta">callId={group.callId}</span>
        </div>
      </header>

      <div className="agent-tool-group__body">
        {group.callItem ? (
          <StructuredDataBlock
            label="arguments"
            preview={`tool=${group.callItem.name}`}
            value={group.callItem.arguments}
          />
        ) : (
          <div className="agent-tool-group__placeholder">missing tool call payload</div>
        )}

        {group.resultItem ? (
          <StructuredDataBlock
            className={group.resultItem.isError ? 'structured-data--error' : undefined}
            label={group.resultItem.isError ? 'error output' : 'output'}
            preview={
              group.resultItem.name ? `tool=${group.resultItem.name}` : `callId=${group.callId}`
            }
            value={group.resultItem.output}
          />
        ) : null}

        {group.childAgents.length > 0 ? (
          <div className="agent-tool-group__children">
            {group.childAgents.map((childAgent) => (
              <AgentSection key={childAgent.agentId} agent={childAgent} />
            ))}
          </div>
        ) : null}
      </div>
    </section>
  )
}

const AgentTimeline = ({ items }: { items: AgentTimelineItem[] }) => {
  if (items.length === 0) {
    return <p className="message-plain agent-response__empty">no trace items</p>
  }

  return (
    <div className="agent-section__timeline">
      {items.map((item) => {
        if (item.type === 'text') {
          return (
            <div key={item.id} className="agent-item agent-item--text">
              {renderMarkdown(item.item.text)}
            </div>
          )
        }

        if (item.type === 'reasoning') {
          return <ReasoningBlock key={item.id} item={item.item} />
        }

        if (item.type === 'tool') {
          return <ToolTraceGroupCard key={item.id} group={item.group} />
        }

        return (
          <section key={item.id} className="agent-item agent-item--unknown">
            <header className="agent-item__header">
              <span className="agent-item__label">unknown output item</span>
            </header>

            <StructuredDataBlock label="raw payload" value={item.item.raw} />
          </section>
        )
      })}
    </div>
  )
}

const AgentSection = ({ agent }: { agent: AgentTreeNode }) => {
  const isOpen = agent.isActive || agent.depth <= 1 || agent.status !== 'completed'

  return (
    <details
      className={`agent-section ${agent.isActive ? 'agent-section--active' : ''}`}
      open={isOpen}
    >
      <summary className="agent-section__summary">
        <div className="agent-section__summary-main">
          <span className="agent-section__name">{agent.agentName}</span>
          <span className={`agent-status agent-status--${agent.status}`}>
            {getStatusLabel(agent.status)}
          </span>
          {agent.isActive ? <span className="agent-chip agent-chip--active">active</span> : null}
        </div>

        <div className="agent-section__summary-meta">
          <span>agentId={agent.agentId}</span>
          <span>depth={agent.depth}</span>
          {agent.sourceCallId ? <span>delegated_from={agent.sourceCallId}</span> : null}
        </div>
      </summary>

      <div className="agent-section__body">
        <WaitingForList agent={agent} />
        <AgentTimeline items={agent.timeline} />

        {agent.childAgents.length > 0 ? (
          <div className="agent-section__children">
            {agent.childAgents.map((childAgent) => (
              <AgentSection key={childAgent.agentId} agent={childAgent} />
            ))}
          </div>
        ) : null}
      </div>
    </details>
  )
}

const findAgentById = (agents: AgentTreeNode[], agentId?: string): AgentTreeNode | null => {
  if (!agentId) {
    return null
  }

  for (const agent of agents) {
    if (agent.agentId === agentId) {
      return agent
    }

    const nestedMatch = findAgentById(
      [
        ...agent.childAgents,
        ...agent.timeline.flatMap((item) =>
          item.type === 'tool' ? item.group.childAgents : [],
        ),
      ],
      agentId,
    )

    if (nestedMatch) {
      return nestedMatch
    }
  }

  return null
}

const AgentResponseBlock = ({ response }: AgentResponseBlockProps) => {
  const activeAgent = findAgentById(response.agents, response.activeAgentId)
  const rootAgent = findAgentById(response.agents, response.rootAgentId)
  const isOpen = response.turnStatus !== 'completed' || response.agents.length <= 1

  return (
    <details className="agent-response" open={isOpen}>
      <summary className="agent-response__summary">
        <div className="agent-response__headline">
          <span className="agent-item__label">assistant turn</span>
          <span className="agent-response__title">
            {rootAgent?.agentName ?? response.rootAgentId}
          </span>
          <span className={`agent-status agent-status--${response.turnStatus}`}>
            {getStatusLabel(response.turnStatus)}
          </span>
        </div>

        <div className="agent-response__meta">
          <span>root={response.rootAgentId}</span>
          {activeAgent ? <span>active={activeAgent.agentName}</span> : null}
          <span>agents={response.agents.length}</span>
        </div>
      </summary>

      <div className="agent-response__body">
        {response.agents.length === 0 ? (
          <p className="message-plain agent-response__empty">no output items</p>
        ) : (
          response.agents.map((agent) => (
            <AgentSection key={agent.agentId} agent={agent} />
          ))
        )}
      </div>
    </details>
  )
}

export default AgentResponseBlock
