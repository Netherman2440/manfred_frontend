import type { FunctionCallAgentItem } from '../types/chat'
import StructuredDataBlock from './StructuredDataBlock'

interface ToolCallCardProps {
  item: FunctionCallAgentItem
}

const ToolCallCard = ({ item }: ToolCallCardProps) => (
  <section className="agent-item agent-item--tool-call">
    <header className="agent-item__header">
      <span className="agent-item__label">tool call</span>
      <span className="agent-item__title">{item.name}</span>
      <span className="agent-item__meta">callId={item.callId}</span>
    </header>

    <StructuredDataBlock
      label="arguments"
      value={item.arguments}
      preview={`tool=${item.name}`}
    />
  </section>
)

export default ToolCallCard
