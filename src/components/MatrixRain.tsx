import { useEffect, useRef } from 'react'

const glyphs = '0123456789'

interface Stream {
  head: number
  length: number
  speed: number
}

const fontSize = 18
const maxDeltaSeconds = 0.05
const backgroundFade = 'rgba(1, 8, 1, 0.16)'

const randomGlyph = () => glyphs[Math.floor(Math.random() * glyphs.length)]

const createStream = (rows: number, startVisible: boolean): Stream => ({
  head: startVisible ? Math.random() * rows : -Math.random() * rows * 1.6,
  length: 8 + Math.floor(Math.random() * 18),
  speed: 10 + Math.random() * 16,
})

const MatrixRain = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current

    if (!canvas) {
      return
    }

    const context = canvas.getContext('2d')

    if (!context) {
      return
    }

    let animationFrameId = 0
    let lastFrameAt: number | null = null
    let streams: Stream[] = []
    let rows = 0

    const resize = () => {
      const ratio = window.devicePixelRatio || 1
      const width = window.innerWidth
      const height = window.innerHeight

      canvas.width = width * ratio
      canvas.height = height * ratio
      canvas.style.width = `${width}px`
      canvas.style.height = `${height}px`

      context.setTransform(ratio, 0, 0, ratio, 0, 0)

      const columnCount = Math.ceil(width / fontSize) + 1
      rows = Math.ceil(height / fontSize) + 1
      streams = Array.from({ length: columnCount }, () =>
        createStream(rows, Math.random() < 0.45),
      )
    }

    const draw = (time: number) => {
      if (lastFrameAt === null) {
        lastFrameAt = time
      }

      const elapsedSeconds = Math.min(
        (time - lastFrameAt) / 1000,
        maxDeltaSeconds,
      )
      lastFrameAt = time
      const width = window.innerWidth
      const height = window.innerHeight

      context.fillStyle = backgroundFade
      context.fillRect(0, 0, width, height)
      context.font = `${fontSize}px "JetBrains Mono", "IBM Plex Mono", monospace`
      context.textBaseline = 'top'
      context.shadowBlur = 8
      context.shadowColor = 'rgba(98, 255, 98, 0.22)'

      streams.forEach((stream, index) => {
        const x = index * fontSize
        stream.head += stream.speed * elapsedSeconds

        if (stream.head - stream.length > rows) {
          streams[index] = createStream(rows, false)
          return
        }

        const headRow = Math.floor(stream.head)

        for (let trailIndex = 0; trailIndex < stream.length; trailIndex += 1) {
          const row = headRow - trailIndex

          if (row < 0 || row > rows) {
            continue
          }

          const y = row * fontSize

          if (trailIndex === 0) {
            context.fillStyle = '#f3fff3'
          } else if (trailIndex < 3) {
            context.fillStyle = `rgba(168, 255, 168, ${0.82 - trailIndex * 0.16})`
          } else {
            const alpha = Math.max(0.06, 0.55 - (trailIndex / stream.length) * 0.48)
            context.fillStyle = `rgba(68, 255, 68, ${alpha})`
          }

          context.fillText(randomGlyph(), x, y)
        }
      })

      context.shadowBlur = 0
      animationFrameId = window.requestAnimationFrame(draw)
    }

    resize()
    context.fillStyle = '#020403'
    context.fillRect(0, 0, window.innerWidth, window.innerHeight)
    animationFrameId = window.requestAnimationFrame(draw)
    window.addEventListener('resize', resize)

    return () => {
      window.cancelAnimationFrame(animationFrameId)
      window.removeEventListener('resize', resize)
    }
  }, [])

  return <canvas ref={canvasRef} className="matrix-rain" aria-hidden="true" />
}

export default MatrixRain
