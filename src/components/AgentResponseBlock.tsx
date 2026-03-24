import type { AgentResponse } from '../types/chat'
import AgentItemView from './AgentItemView'

interface AgentResponseBlockProps {
  response: AgentResponse
}

const AgentResponseBlock = ({ response }: AgentResponseBlockProps) => {
  if (response.items.length === 0) {
    return <p className="message-plain agent-response__empty">no output items</p>
  }

  return (
    <div className="agent-response">
      {response.agentName || response.agentId !== 'assistant' ? (
        <div className="agent-response__meta">
          <span>{response.agentName ?? response.agentId}</span>
          {typeof response.depth === 'number' ? <span>depth={response.depth}</span> : null}
        </div>
      ) : null}

      <div className="agent-response__items">
        {response.items.map((item) => (
          <AgentItemView key={item.id} item={item} />
        ))}
      </div>
    </div>
  )
}

export default AgentResponseBlock
