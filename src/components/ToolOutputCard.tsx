import type { FunctionCallOutputAgentItem } from '../types/chat'
import StructuredDataBlock from './StructuredDataBlock'

interface ToolOutputCardProps {
  item: FunctionCallOutputAgentItem
}

const ToolOutputCard = ({ item }: ToolOutputCardProps) => (
  <section
    className={`agent-item agent-item--tool-output ${item.isError ? 'agent-item--error' : ''}`}
  >
    <header className="agent-item__header">
      <span className="agent-item__label">
        {item.isError ? 'tool output error' : 'tool output'}
      </span>
      <span className="agent-item__title">{item.name ?? 'unknown tool'}</span>
      <span className="agent-item__meta">callId={item.callId}</span>
    </header>

    <StructuredDataBlock
      label={item.isError ? 'error output' : 'output'}
      value={item.output}
      preview={item.name ? `tool=${item.name}` : undefined}
    />
  </section>
)

export default ToolOutputCard
