import type {
  AgentExecutionStatus,
  AgentItem,
  AgentTimelineItem,
  AgentTreeNode,
  FunctionCallAgentItem,
  FunctionCallOutputAgentItem,
  TurnExecutionStatus,
  WaitingForState,
} from '../types/chat'

interface RawTextValue {
  value?: unknown
}

interface RawOutputItem {
  id?: unknown
  type?: unknown
  text?: unknown
  summary?: unknown
  content?: unknown
  name?: unknown
  callId?: unknown
  call_id?: unknown
  arguments?: unknown
  output?: unknown
  isError?: unknown
  is_error?: unknown
  metadata?: unknown
}

interface AgentPayloadNode {
  id: string
  name: string
  parentId?: string
  sourceCallId?: string
  depth: number
  status: AgentExecutionStatus
  waitingFor?: WaitingForState[]
  items: AgentItem[]
  children: AgentPayloadNode[]
  order: number
}

interface AgentNodeRuntime {
  node: AgentTreeNode
  toolGroups: Map<string, Extract<AgentTimelineItem, { type: 'tool' }>['group']>
  order: number
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value)

const readOptionalString = (value: unknown) =>
  typeof value === 'string' && value.length > 0 ? value : undefined

const readOptionalNumber = (value: unknown) => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }

  if (typeof value === 'string' && value.trim().length > 0) {
    const parsedValue = Number(value)

    return Number.isFinite(parsedValue) ? parsedValue : undefined
  }

  return undefined
}

const ensureObjectRecord = (value: unknown) =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined

const safeParseJson = (value: string) => {
  try {
    return JSON.parse(value) as unknown
  } catch {
    return value
  }
}

const readTextValue = (value: unknown): string | undefined => {
  if (typeof value === 'string' && value.length > 0) {
    return value
  }

  if (value && typeof value === 'object') {
    const rawTextValue = value as RawTextValue

    return typeof rawTextValue.value === 'string' && rawTextValue.value.length > 0
      ? rawTextValue.value
      : undefined
  }

  return undefined
}

const collectOutputText = (value: unknown): string[] => {
  if (!value) {
    return []
  }

  if (typeof value === 'string') {
    return value.length > 0 ? [value] : []
  }

  if (Array.isArray(value)) {
    return value.flatMap((item) => collectOutputText(item))
  }

  if (!isRecord(value)) {
    return []
  }

  const textValue =
    typeof value.text === 'string'
      ? value.text
      : value.text && typeof value.text === 'object'
        ? (value.text as RawTextValue).value
        : undefined

  const texts: string[] = []

  if (
    (value.type === 'text' ||
      value.type === 'output_text' ||
      value.type === 'assistant_message' ||
      typeof value.type === 'undefined') &&
    typeof textValue === 'string' &&
    textValue.length > 0
  ) {
    texts.push(textValue)
  }

  if (value.content) {
    texts.push(...collectOutputText(value.content))
  }

  return texts
}

const readContentText = (value: unknown): string | undefined => {
  const texts = collectOutputText(value)

  return texts.length > 0 ? texts.join('\n\n').trim() : undefined
}

const normalizeToolArguments = (value: unknown) => {
  if (typeof value === 'string') {
    return safeParseJson(value)
  }

  return value
}

const normalizeToolOutput = (value: unknown) => {
  if (typeof value === 'string') {
    return safeParseJson(value)
  }

  return value
}

const createUnknownItem = (raw: unknown): AgentItem => ({
  id: crypto.randomUUID(),
  type: 'unknown',
  raw,
})

export const normalizeOutputItem = (raw: unknown): AgentItem[] => {
  if (!raw || typeof raw !== 'object') {
    return [createUnknownItem(raw)]
  }

  const item = raw as RawOutputItem
  const id = readOptionalString(item.id) ?? crypto.randomUUID()
  const type = readOptionalString(item.type)
  const text = readTextValue(item.text)
  const contentText = readContentText(item.content)
  const summary = readTextValue(item.summary)
  const name = readOptionalString(item.name)
  const callId = readOptionalString(item.callId ?? item.call_id)

  switch (type) {
    case 'text':
    case 'output_text':
    case 'assistant_message':
      return text ?? contentText
        ? [
            {
              id,
              type: 'text',
              text: text ?? contentText ?? '',
            },
          ]
        : [createUnknownItem(raw)]
    case 'reasoning':
    case 'reasoning_summary':
      return text || summary
        ? [
            {
              id,
              type: 'reasoning',
              text,
              summary,
              metadata: ensureObjectRecord(item.metadata),
            },
          ]
        : [createUnknownItem(raw)]
    case 'function_call':
    case 'tool_call':
      return callId && name
        ? [
            {
              id,
              type: 'function_call',
              callId,
              name,
              arguments: normalizeToolArguments(item.arguments),
            },
          ]
        : [createUnknownItem(raw)]
    case 'function_call_output':
    case 'tool_result':
      return callId
        ? [
            {
              id,
              type: 'function_call_output',
              callId,
              name,
              output: normalizeToolOutput(item.output),
              isError:
                typeof item.isError === 'boolean'
                  ? item.isError
                  : typeof item.is_error === 'boolean'
                    ? item.is_error
                    : undefined,
            },
          ]
        : [createUnknownItem(raw)]
    case 'message': {
      if (!Array.isArray(item.content)) {
        return [createUnknownItem(raw)]
      }

      const nestedItems = item.content.flatMap((contentItem) => normalizeOutputItem(contentItem))

      return nestedItems.length > 0 ? nestedItems : [createUnknownItem(raw)]
    }
    default:
      return !type && (text ?? contentText)
        ? [
            {
              id,
              type: 'text',
              text: text ?? contentText ?? '',
            },
          ]
        : [createUnknownItem(raw)]
  }
}

export const normalizeAgentItems = (rawOutput: unknown[]): AgentItem[] => {
  const normalizedItems = rawOutput.flatMap((rawItem) => normalizeOutputItem(rawItem))

  return normalizedItems.length > 0 ? normalizedItems : []
}

const normalizeStatus = (value: unknown): AgentExecutionStatus => {
  switch (value) {
    case 'pending':
    case 'running':
    case 'waiting':
    case 'completed':
    case 'failed':
    case 'cancelled':
      return value
    default:
      return 'completed'
  }
}

export const normalizeTurnStatus = (value: unknown): TurnExecutionStatus =>
  normalizeStatus(value)

const stringifyFallback = (value: unknown) => {
  if (typeof value === 'string' && value.trim().length > 0) {
    return value.trim()
  }

  try {
    const serialized = JSON.stringify(value)

    return typeof serialized === 'string' && serialized !== '{}' ? serialized : 'unknown'
  } catch {
    return 'unknown'
  }
}

export const normalizeWaitingFor = (value: unknown): WaitingForState[] | undefined => {
  if (!Array.isArray(value)) {
    return undefined
  }

  const waitingFor = value.flatMap((entry, index) => {
    if (typeof entry === 'string') {
      return [
        {
          id: `waiting-${index}`,
          label: entry,
          raw: entry,
        },
      ]
    }

    if (!isRecord(entry)) {
      return [
        {
          id: `waiting-${index}`,
          label: stringifyFallback(entry),
          raw: entry,
        },
      ]
    }

    const id =
      readOptionalString(entry.id) ??
      readOptionalString(entry.callId) ??
      readOptionalString(entry.call_id) ??
      `waiting-${index}`
    const kind =
      readOptionalString(entry.kind) ??
      readOptionalString(entry.type) ??
      readOptionalString(entry.reason)
    const label =
      readOptionalString(entry.label) ??
      readOptionalString(entry.name) ??
      readOptionalString(entry.description) ??
      readOptionalString(entry.message) ??
      kind ??
      stringifyFallback(entry)

    return [
      {
        id,
        label,
        kind,
        raw: entry,
      },
    ]
  })

  return waitingFor.length > 0 ? waitingFor : undefined
}

const readAgentItemsPayload = (value: Record<string, unknown>) => {
  if (Array.isArray(value.items)) {
    return value.items
  }

  if (Array.isArray(value.output)) {
    return value.output
  }

  if (Array.isArray(value.timeline)) {
    return value.timeline
  }

  return []
}

const normalizeAgentPayload = (
  value: unknown,
  order: number,
  depthFallback = 0,
  parentIdFallback?: string,
): AgentPayloadNode | null => {
  if (!isRecord(value)) {
    return null
  }

  const id =
    readOptionalString(value.id) ??
    readOptionalString(value.agentId) ??
    readOptionalString(value.agent_id)

  if (!id) {
    return null
  }

  const children = Array.isArray(value.children)
    ? value.children
        .map((child, childIndex) =>
          normalizeAgentPayload(child, order * 1000 + childIndex, depthFallback + 1, id),
        )
        .filter((child): child is AgentPayloadNode => child !== null)
    : []

  return {
    id,
    name:
      readOptionalString(value.name) ??
      readOptionalString(value.agentName) ??
      readOptionalString(value.agent_name) ??
      readOptionalString(value.displayName) ??
      readOptionalString(value.display_name) ??
      id,
    parentId:
      readOptionalString(value.parentId) ??
      readOptionalString(value.parentAgentId) ??
      readOptionalString(value.parent_agent_id) ??
      readOptionalString(value.parent_id) ??
      parentIdFallback,
    sourceCallId: readOptionalString(value.sourceCallId ?? value.source_call_id),
    depth: readOptionalNumber(value.depth) ?? depthFallback,
    status: normalizeStatus(value.status),
    waitingFor: normalizeWaitingFor(value.waitingFor ?? value.waiting_for),
    items: normalizeAgentItems(readAgentItemsPayload(value)),
    children,
    order,
  }
}

const flattenAgentPayload = (node: AgentPayloadNode): AgentPayloadNode[] => [
  {
    ...node,
    children: [],
  },
  ...node.children.flatMap((child) => flattenAgentPayload(child)),
]

const buildAgentTimeline = (items: AgentItem[]) => {
  const timeline: AgentTimelineItem[] = []
  const toolGroups = new Map<string, Extract<AgentTimelineItem, { type: 'tool' }>['group']>()

  items.forEach((item) => {
    if (item.type === 'text') {
      timeline.push({
        id: item.id,
        type: 'text',
        item,
      })
      return
    }

    if (item.type === 'reasoning') {
      timeline.push({
        id: item.id,
        type: 'reasoning',
        item,
      })
      return
    }

    if (item.type === 'unknown') {
      timeline.push({
        id: item.id,
        type: 'unknown',
        item,
      })
      return
    }

    const toolName =
      item.type === 'function_call'
        ? item.name
        : item.name && item.name.length > 0
          ? item.name
          : 'unknown tool'
    const group = toolGroups.get(item.callId)

    if (item.type === 'function_call') {
      if (group) {
        group.callItem = item
        group.toolName = item.name
        return
      }

      const nextGroup = {
        callId: item.callId,
        toolName: item.name,
        callItem: item,
        childAgents: [],
      }

      toolGroups.set(item.callId, nextGroup)
      timeline.push({
        id: item.id,
        type: 'tool',
        group: nextGroup,
      })
      return
    }

    if (group) {
      group.resultItem = item
      group.toolName = group.callItem?.name ?? toolName
      return
    }

    const nextGroup = {
      callId: item.callId,
      toolName,
      resultItem: item,
      childAgents: [],
    }

    toolGroups.set(item.callId, nextGroup)
    timeline.push({
      id: item.id,
      type: 'tool',
      group: nextGroup,
    })
  })

  return {
    timeline,
    toolGroups,
  }
}

const createRuntimeNode = (
  payload: AgentPayloadNode,
  activeAgentId?: string,
): AgentNodeRuntime => {
  const { timeline, toolGroups } = buildAgentTimeline(payload.items)

  return {
    node: {
      agentId: payload.id,
      agentName: payload.name,
      status: payload.status,
      depth: payload.depth,
      parentAgentId: payload.parentId,
      sourceCallId: payload.sourceCallId,
      waitingFor: payload.waitingFor,
      timeline,
      childAgents: [],
      isActive: payload.id === activeAgentId,
    },
    toolGroups,
    order: payload.order,
  }
}

const sortNodes = (nodes: AgentNodeRuntime[]) => nodes.sort((left, right) => left.order - right.order)

const attachChildNode = (
  parentRuntime: AgentNodeRuntime,
  childNode: AgentTreeNode,
  sourceCallId?: string,
) => {
  if (sourceCallId) {
    const toolGroup = parentRuntime.toolGroups.get(sourceCallId)

    if (toolGroup) {
      toolGroup.childAgents.push(childNode)
      return
    }
  }

  parentRuntime.node.childAgents.push(childNode)
}

export interface NormalizedChatTrace {
  rootAgentId: string
  activeAgentId?: string
  turnStatus: TurnExecutionStatus
  agents: AgentTreeNode[]
}

export const normalizeStoredAgentTimeline = (value: unknown): AgentTimelineItem[] => {
  if (!Array.isArray(value)) {
    return []
  }

  return value.reduce<AgentTimelineItem[]>((items, entry) => {
    if (!isRecord(entry) || typeof entry.type !== 'string') {
      return items
    }

    if (entry.type === 'text') {
      const textItem = normalizeOutputItem({
        id: entry.item && isRecord(entry.item) ? entry.item.id : entry.id,
        type: 'text',
        text: entry.item && isRecord(entry.item) ? entry.item.text : undefined,
      })[0]

      if (textItem && textItem.type === 'text') {
        items.push({
          id: textItem.id,
          type: 'text',
          item: textItem,
        })
      }

      return items
    }

    if (entry.type === 'reasoning') {
      const reasoningItem = normalizeOutputItem({
        id: entry.item && isRecord(entry.item) ? entry.item.id : entry.id,
        type: 'reasoning',
        text: entry.item && isRecord(entry.item) ? entry.item.text : undefined,
        summary: entry.item && isRecord(entry.item) ? entry.item.summary : undefined,
        metadata: entry.item && isRecord(entry.item) ? entry.item.metadata : undefined,
      })[0]

      if (reasoningItem && reasoningItem.type === 'reasoning') {
        items.push({
          id: reasoningItem.id,
          type: 'reasoning',
          item: reasoningItem,
        })
      }

      return items
    }

    if (entry.type === 'unknown') {
      items.push({
        id: readOptionalString(entry.id) ?? crypto.randomUUID(),
        type: 'unknown',
        item: {
          id:
            readOptionalString(entry.item && isRecord(entry.item) ? entry.item.id : entry.id) ??
            crypto.randomUUID(),
          type: 'unknown',
          raw: entry.item && isRecord(entry.item) ? entry.item.raw : entry.raw,
        },
      })

      return items
    }

    if (entry.type === 'tool' && isRecord(entry.group)) {
      const callItem = normalizeStoredCallItem(entry.group.callItem)
      const resultItem = normalizeStoredOutputItem(entry.group.resultItem)
      const childAgents = normalizeStoredAgentTree(entry.group.childAgents)

      if (!callItem && !resultItem) {
        return items
      }

      items.push({
        id: readOptionalString(entry.id) ?? callItem?.id ?? resultItem?.id ?? crypto.randomUUID(),
        type: 'tool',
        group: {
          callId:
            callItem?.callId ??
            resultItem?.callId ??
            readOptionalString(entry.group.callId) ??
            crypto.randomUUID(),
          toolName:
            callItem?.name ??
            resultItem?.name ??
            readOptionalString(entry.group.toolName) ??
            'unknown tool',
          callItem: callItem ?? undefined,
          resultItem: resultItem ?? undefined,
          childAgents,
        },
      })
    }

    return items
  }, [])
}

const normalizeStoredCallItem = (value: unknown): FunctionCallAgentItem | null => {
  if (!isRecord(value)) {
    return null
  }

  const [item] = normalizeOutputItem({
    id: value.id,
    type: 'function_call',
    callId: value.callId,
    name: value.name,
    arguments: value.arguments,
  })

  return item?.type === 'function_call' ? item : null
}

const normalizeStoredOutputItem = (value: unknown): FunctionCallOutputAgentItem | null => {
  if (!isRecord(value)) {
    return null
  }

  const [item] = normalizeOutputItem({
    id: value.id,
    type: 'function_call_output',
    callId: value.callId,
    name: value.name,
    output: value.output,
    isError: value.isError,
  })

  return item?.type === 'function_call_output' ? item : null
}

export const normalizeStoredAgentTree = (value: unknown): AgentTreeNode[] => {
  if (!Array.isArray(value)) {
    return []
  }

  return value.flatMap((entry) => {
    if (!isRecord(entry)) {
      return []
    }

    const agentId = readOptionalString(entry.agentId)

    if (!agentId) {
      return []
    }

    return [
      {
        agentId,
        agentName: readOptionalString(entry.agentName) ?? agentId,
        status: normalizeStatus(entry.status),
        depth: readOptionalNumber(entry.depth) ?? 0,
        parentAgentId: readOptionalString(entry.parentAgentId),
        sourceCallId: readOptionalString(entry.sourceCallId),
        waitingFor: normalizeWaitingFor(entry.waitingFor),
        timeline: normalizeStoredAgentTimeline(entry.timeline),
        childAgents: normalizeStoredAgentTree(entry.childAgents),
        isActive: entry.isActive === true,
      },
    ]
  })
}

export const normalizeChatTrace = (value: unknown): NormalizedChatTrace => {
  const data = isRecord(value) ? value : {}
  const rawAgents = Array.isArray(data.agents) ? data.agents : []
  const payloadAgents =
    rawAgents.length > 0
      ? rawAgents
          .map((agent, index) => normalizeAgentPayload(agent, index))
          .filter((agent): agent is AgentPayloadNode => agent !== null)
      : [
          normalizeAgentPayload(
            {
              id: data.rootAgentId ?? data.agentId ?? data.agent_id ?? 'assistant',
              name: data.agentName ?? data.agent_name,
              parentId: data.parentAgentId ?? data.parent_agent_id,
              depth: data.depth,
              status: data.status ?? data.turnStatus ?? data.turn_status,
              waitingFor: data.waitingFor ?? data.waiting_for,
              items: data.items ?? data.output ?? data.timeline,
            },
            0,
          ),
        ].filter((agent): agent is AgentPayloadNode => agent !== null)
  const flatAgents = payloadAgents.flatMap((agent) => flattenAgentPayload(agent))
  const activeAgentId =
    readOptionalString(data.activeAgentId) ?? readOptionalString(data.active_agent_id)
  const runtimes = new Map<string, AgentNodeRuntime>(
    flatAgents.map((agent) => [agent.id, createRuntimeNode(agent, activeAgentId)]),
  )

  flatAgents.forEach((agent) => {
    const runtime = runtimes.get(agent.id)

    if (!runtime) {
      return
    }

    if (!agent.parentId) {
      return
    }

    const parentRuntime = runtimes.get(agent.parentId)

    if (!parentRuntime) {
      return
    }

    attachChildNode(parentRuntime, runtime.node, agent.sourceCallId)
  })

  const rootAgents = sortNodes(
    flatAgents
      .filter((agent) => !agent.parentId || !runtimes.has(agent.parentId))
      .map((agent) => runtimes.get(agent.id))
      .filter((agent): agent is AgentNodeRuntime => Boolean(agent)),
  ).map((runtime) => runtime.node)

  return {
    rootAgentId:
      readOptionalString(data.rootAgentId) ??
      readOptionalString(data.root_agent_id) ??
      rootAgents[0]?.agentId ??
      readOptionalString(data.agentId ?? data.agent_id) ??
      'assistant',
    activeAgentId,
    turnStatus: normalizeTurnStatus(data.turnStatus ?? data.turn_status ?? data.status),
    agents: rootAgents,
  }
}
