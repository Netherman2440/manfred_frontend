import { lazy, Suspense } from 'react'
import type { AgentItem } from '../types/chat'
import ReasoningBlock from './ReasoningBlock'
import StructuredDataBlock from './StructuredDataBlock'
import ToolCallCard from './ToolCallCard'
import ToolOutputCard from './ToolOutputCard'

const AssistantMarkdown = lazy(() => import('./AssistantMarkdown'))

interface AgentItemViewProps {
  item: AgentItem
}

const AgentItemView = ({ item }: AgentItemViewProps) => {
  switch (item.type) {
    case 'text':
      return (
        <div className="agent-item agent-item--text">
          <Suspense fallback={<p className="message-plain">{item.text}</p>}>
            <AssistantMarkdown content={item.text} />
          </Suspense>
        </div>
      )
    case 'reasoning':
      return <ReasoningBlock item={item} />
    case 'function_call':
      return <ToolCallCard item={item} />
    case 'function_call_output':
      return <ToolOutputCard item={item} />
    case 'unknown':
      return (
        <section className="agent-item agent-item--unknown">
          <header className="agent-item__header">
            <span className="agent-item__label">unknown output item</span>
          </header>

          <StructuredDataBlock label="raw payload" value={item.raw} />
        </section>
      )
    default:
      return null
  }
}

export default AgentItemView
