interface StructuredDataBlockProps {
  className?: string
  label: string
  preview?: string
  value: unknown
  defaultOpen?: boolean
}

const maxPreviewLength = 140

const stringifyStructuredValue = (value: unknown) => {
  if (typeof value === 'string') {
    return value
  }

  if (typeof value === 'undefined') {
    return 'undefined'
  }

  try {
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

const createStructuredPreview = (value: unknown) => {
  const serializedValue = stringifyStructuredValue(value).replace(/\s+/g, ' ').trim()

  if (serializedValue.length <= maxPreviewLength) {
    return serializedValue
  }

  return `${serializedValue.slice(0, maxPreviewLength - 1)}…`
}

const StructuredDataBlock = ({
  className,
  label,
  preview,
  value,
  defaultOpen = false,
}: StructuredDataBlockProps) => (
  <details
    className={className ? `structured-data ${className}` : 'structured-data'}
    open={defaultOpen}
  >
    <summary className="structured-data__summary">
      <span>{label}</span>
      <span className="structured-data__preview">
        {preview ?? createStructuredPreview(value)}
      </span>
    </summary>

    <pre className="structured-data__body">{stringifyStructuredValue(value)}</pre>
  </details>
)

export default StructuredDataBlock
