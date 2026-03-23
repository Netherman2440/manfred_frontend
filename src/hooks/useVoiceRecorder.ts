import { useEffect, useRef, useState } from 'react'

const supportedMimeTypes = [
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/ogg;codecs=opus',
  'audio/mp4',
]

const defaultExtensionByMimeType: Record<string, string> = {
  'audio/mp4': 'm4a',
  'audio/ogg;codecs=opus': 'ogg',
  'audio/webm': 'webm',
  'audio/webm;codecs=opus': 'webm',
}

const resolveSupportedMimeType = () => {
  if (typeof window === 'undefined' || typeof MediaRecorder === 'undefined') {
    return null
  }

  for (const mimeType of supportedMimeTypes) {
    if (MediaRecorder.isTypeSupported(mimeType)) {
      return mimeType
    }
  }

  return ''
}

const stopStream = (stream: MediaStream | null) => {
  stream?.getTracks().forEach((track) => {
    track.stop()
  })
}

export interface RecordedAudio {
  blob: Blob
  extension: string
  mimeType: string
}

export const useVoiceRecorder = () => {
  const [isSupported] = useState(() => {
    return typeof window !== 'undefined' && typeof MediaRecorder !== 'undefined'
  })
  const [isRecording, setIsRecording] = useState(false)
  const [durationMs, setDurationMs] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const chunksRef = useRef<Blob[]>([])
  const timerRef = useRef<number | null>(null)
  const startedAtRef = useRef<number | null>(null)
  const cancelOnStopRef = useRef(false)
  const pendingStopResolveRef = useRef<((value: RecordedAudio | null) => void) | null>(null)
  const pendingStopRejectRef = useRef<((reason?: unknown) => void) | null>(null)

  useEffect(
    () => () => {
      if (timerRef.current) {
        window.clearInterval(timerRef.current)
      }

      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        cancelOnStopRef.current = true
        mediaRecorderRef.current.stop()
      }

      stopStream(streamRef.current)
    },
    [],
  )

  const startRecording = async () => {
    if (!isSupported || isRecording) {
      return
    }

    const mimeType = resolveSupportedMimeType()

    if (mimeType === null) {
      setError('Ta przegladarka nie obsluguje nagrywania audio.')
      return
    }

    if (!navigator.mediaDevices?.getUserMedia) {
      setError('Brak dostepu do mikrofonu w tej przegladarce.')
      return
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream)

      chunksRef.current = []
      cancelOnStopRef.current = false
      startedAtRef.current = Date.now()
      setDurationMs(0)
      setError(null)

      recorder.addEventListener('dataavailable', (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data)
        }
      })

      recorder.addEventListener('stop', () => {
        if (timerRef.current) {
          window.clearInterval(timerRef.current)
          timerRef.current = null
        }

        setIsRecording(false)
        stopStream(streamRef.current)
        streamRef.current = null

        const resolve = pendingStopResolveRef.current
        pendingStopResolveRef.current = null
        pendingStopRejectRef.current = null

        if (cancelOnStopRef.current) {
          cancelOnStopRef.current = false
          chunksRef.current = []
          resolve?.(null)
          return
        }

        const selectedMimeType = recorder.mimeType || mimeType || 'audio/webm'
        const blob = new Blob(chunksRef.current, {
          type: selectedMimeType,
        })
        const extension = defaultExtensionByMimeType[selectedMimeType] ?? 'webm'

        chunksRef.current = []
        resolve?.({
          blob,
          extension,
          mimeType: selectedMimeType,
        })
      })

      recorder.addEventListener('error', (event) => {
        if (timerRef.current) {
          window.clearInterval(timerRef.current)
          timerRef.current = null
        }

        setIsRecording(false)
        stopStream(stream)
        streamRef.current = null
        setError(event.error?.message ?? 'Nagrywanie nie powiodlo sie.')
        pendingStopRejectRef.current?.(event.error)
        pendingStopResolveRef.current = null
        pendingStopRejectRef.current = null
      })

      streamRef.current = stream
      mediaRecorderRef.current = recorder
      setIsRecording(true)

      timerRef.current = window.setInterval(() => {
        const startedAt = startedAtRef.current

        if (!startedAt) {
          return
        }

        setDurationMs(Date.now() - startedAt)
      }, 250)

      recorder.start()
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : 'Brak dostepu do mikrofonu.',
      )
    }
  }

  const stopRecording = () => {
    const recorder = mediaRecorderRef.current

    if (!recorder || recorder.state === 'inactive') {
      return Promise.resolve<RecordedAudio | null>(null)
    }

    return new Promise<RecordedAudio | null>((resolve, reject) => {
      pendingStopResolveRef.current = resolve
      pendingStopRejectRef.current = reject
      recorder.stop()
    })
  }

  const cancelRecording = async () => {
    const recorder = mediaRecorderRef.current

    if (!recorder || recorder.state === 'inactive') {
      setIsRecording(false)
      setDurationMs(0)
      return
    }

    cancelOnStopRef.current = true
    await stopRecording()
    setDurationMs(0)
  }

  return {
    durationMs,
    error,
    isRecording,
    isSupported,
    startRecording,
    stopRecording,
    cancelRecording,
  }
}
