import { Markdown } from '@copilotkit/react-ui'

interface AssistantMarkdownProps {
  content: string
}

const AssistantMarkdown = ({ content }: AssistantMarkdownProps) => (
  <Markdown content={content} />
)

export default AssistantMarkdown
