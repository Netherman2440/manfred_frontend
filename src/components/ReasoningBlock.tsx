import { lazy, Suspense } from 'react'
import type { ReasoningAgentItem } from '../types/chat'
import StructuredDataBlock from './StructuredDataBlock'

const AssistantMarkdown = lazy(() => import('./AssistantMarkdown'))

interface ReasoningBlockProps {
  item: ReasoningAgentItem
}

const ReasoningBlock = ({ item }: ReasoningBlockProps) => {
  const content = item.text ?? item.summary ?? ''

  return (
    <details className="agent-item agent-item--reasoning">
      <summary className="agent-item__summary">
        <span className="agent-item__label">reasoning</span>
        <span className="agent-item__preview">
          {item.summary ?? (content.length > 96 ? `${content.slice(0, 95)}…` : content)}
        </span>
      </summary>

      <div className="agent-item__body">
        {content ? (
          <Suspense fallback={<p className="message-plain">{content}</p>}>
            <AssistantMarkdown content={content} />
          </Suspense>
        ) : null}

        {item.metadata ? (
          <StructuredDataBlock label="metadata" value={item.metadata} />
        ) : null}
      </div>
    </details>
  )
}

export default ReasoningBlock
