# Plan dostosowania frontendu do nowego API chat + attachments + voice

## Cel

Dostosować `manfred_frontend` do nowego kontraktu backendu tak, aby użytkownik mógł:

- pisać zwykłe wiadomości tekstowe,
- dodawać pliki i obrazy z poziomu UI,
- nagrywać wiadomości głosowe,
- wysyłać wiadomość tekstową wraz z wcześniej załadowanymi attachmentami,
- wysyłać samą wiadomość głosową bez tekstu.

## Stan obecny

- frontend korzysta z legacy endpointu `/api/v1/chat`,
- payload opiera się o `thread_id`,
- odpowiedź oczekuje prostego `{ message }`,
- UI nie ma attachment queue, file uploadu ani voice recordera.

To trzeba potraktować jako migrację kontraktu, nie mały refactor.

## Założenie integracyjne

Frontend przechodzi na dwa wywołania backendu:

1. `POST /api/v1/chat/attachments`
2. `POST /api/v1/chat/completions`

To jest ważne, bo pliki mają trafiać do `workspace/input/...` od razu po wybraniu/nagraniu, a sama tura chatu ma operować już na referencjach do tych plików.

## Docelowy flow w UI

### Scenariusz: zwykły plik lub obraz

1. Użytkownik wybiera plik.
2. Frontend od razu wysyła go do `POST /api/v1/chat/attachments`.
3. Backend zwraca `sessionId` i attachment metadata.
4. UI pokazuje attachment jako gotowy do wysłania.
5. Po kliknięciu `send` frontend wywołuje `POST /api/v1/chat/completions` z:
   - `sessionId`
   - `message`
   - `attachmentIds`

### Scenariusz: voice

1. Użytkownik klika `record`.
2. Frontend nagrywa audio przez `MediaRecorder`.
3. Po `stop` frontend wysyła blob audio do `POST /api/v1/chat/attachments`.
4. Backend zapisuje plik i wykonuje transkrypcję.
5. UI pokazuje attachment audio i opcjonalnie status transkrypcji.
6. Użytkownik może:
   - wysłać samo audio,
   - albo dodać tekst i wysłać audio + tekst razem.

## Zmiany w stanie aplikacji

### 1. Zamiana `threadId` na prawdziwe `sessionId`

Obecny `threadId` generowany lokalnie nie może dalej pełnić roli identyfikatora sesji. Trzeba przejść na:

- `sessionId: string | null`
- `messages: ChatMessage[]`
- `pendingAttachments: PendingAttachment[]`
- `uploadingAttachments: UploadState[]`
- `recorderState`

`sessionId` powinno pochodzić wyłącznie z backendu:

- z odpowiedzi uploadu,
- albo z pierwszego `chat/completions`, jeśli wiadomość została wysłana bez attachmentów.

### 2. Nowe typy frontowe

Dodać typy:

```ts
type AttachmentKind = 'image' | 'document' | 'audio' | 'other'

interface ChatAttachment {
  id: string
  kind: AttachmentKind
  mimeType: string
  originalFilename: string
  workspacePath: string
  sizeBytes: number
  transcription?: {
    status: 'pending' | 'completed' | 'failed'
    text?: string
  }
}
```

oraz rozszerzyć model wiadomości o attachmenty przypisane do bubble usera.

## Zmiany w warstwie API klienta

### 1. Zastąpić obecne `sendChatMessage`

Obecne `src/lib/chat-api.ts` trzeba rozdzielić na:

- `uploadAttachments(payload)`
- `sendChatCompletion(payload)`

Rekomendowany zakres:

- upload oparty o `FormData`,
- chat oparty o JSON,
- wspólna normalizacja błędów,
- osobne typy odpowiedzi dla uploadu i completions.

### 2. Normalizacja odpowiedzi backendu

Frontend nie powinien już zakładać odpowiedzi w formie pojedynczego `message`.

Powinien:

- czytać `sessionId`,
- czytać `output[]`,
- z `output[]` wyciągać elementy `text`,
- opcjonalnie pokazywać `function_call` w trybie developerskim albo ignorować je w pierwszej wersji.

## Zmiany w UI

### 1. Composer

Dodać do composera:

- przycisk `attach`,
- ukryty `input type="file"` z możliwością multiselect,
- przycisk `record / stop`,
- listę attachment chips przed wysłaniem.

Każdy chip powinien pokazywać:

- nazwę pliku,
- status uploadu,
- status transkrypcji dla audio,
- możliwość usunięcia attachmentu z pending listy przed wysłaniem.

### 2. Rendering wiadomości użytkownika

Bubble usera nie może już być tylko czystym tekstem. Powinna wyświetlać:

- treść wiadomości,
- listę attachmentów,
- dla audio opcjonalnie:
  - nazwę pliku,
  - krótki snippet transkrypcji,
  - status `transcribing...` jeśli backend kiedyś przejdzie na async.

### 3. Voice recorder

Pierwsza wersja powinna być minimalistyczna:

- `MediaRecorder`
- preferowany `audio/webm`
- fallback na pierwszy wspierany typ z `MediaRecorder.isTypeSupported(...)`
- prosty timer nagrania
- `cancel` usuwa blob lokalnie i nie robi uploadu

Nie ma potrzeby budować playera audio w pierwszym etapie, jeśli nie jest potrzebny do UX.

## Zachowanie przy wysyłce

### Reguły walidacji w UI

- `send` aktywne, gdy istnieje:
  - niepusty tekst,
  - albo co najmniej jeden gotowy attachment,
- `send` zablokowane podczas aktywnego uploadu,
- `send` zablokowane podczas nagrywania,
- `abort` powinno przerywać wyłącznie request `chat/completions`, nie kończyć istniejących już attachmentów zapisanych w backendzie.

### Po sukcesie

- wyczyścić draft,
- wyczyścić `pendingAttachments`,
- zachować `sessionId`,
- dodać user message i assistant message do lokalnego stanu,
- zapisać `sessionId` w local storage.

## Local storage i odświeżenie strony

Obecny storage oparty o `threadId` trzeba zmienić na:

- `sessionId`
- `messages`

Nie rekomenduję przechowywania `pendingAttachments` po refreshu w pierwszej wersji. To komplikuje recovery i łatwo prowadzi do nieaktualnych referencji.

Jeśli użytkownik odświeży stronę po wysłaniu uploadu, ale przed `send`, attachmenty mogą zostać utracone po stronie UI. To jest akceptowalne w wersji 1.

## Zmiany w komponencie `App.tsx`

Najbezpieczniej rozdzielić obecną logikę na mniejsze części:

- `useChatSession()`
- `useAttachmentUpload()`
- `useVoiceRecorder()`
- `ChatComposer`
- `AttachmentList`

Nie trzeba robić pełnej przebudowy architektury, ale dalsze dokładanie wszystkiego do jednego `App.tsx` będzie szybko nieczytelne.

## Migracja krok po kroku

### Etap 1

- przepiąć frontend z `/api/v1/chat` na `/api/v1/chat/completions`,
- przejść z `thread_id` na `sessionId`,
- czytać odpowiedź `output[]`.

### Etap 2

- dodać upload zwykłych plików i obrazów,
- dodać attachment queue w composerze,
- wysyłać `attachmentIds` razem z wiadomością.

### Etap 3

- dodać voice recording przez `MediaRecorder`,
- upload audio do backendu,
- obsłużyć stan transkrypcji i voice-only message.

## Testy frontendowe

### Manualne

- wysłanie zwykłej wiadomości tekstowej bez attachmentów
- wysłanie wiadomości z jednym PDF
- wysłanie wiadomości z jednym obrazem
- wysłanie wiadomości z wieloma attachmentami
- nagranie audio i wysłanie bez tekstu
- nagranie audio i wysłanie z tekstem
- reset sesji po rozpoczętej rozmowie
- odświeżenie strony po zakończonej rozmowie

### Automaty lub lekkie testy komponentów

- parser odpowiedzi `output[] -> assistant text`
- reducer/state update dla attachment queue
- walidacja `send enabled/disabled`
- obsługa błędów uploadu

## Ryzyka

- próba utrzymania kompatybilności z lokalnym `threadId` tylko zwiększy chaos migracyjny,
- upload i send mają różne lifecycle, więc trzeba rozdzielić ich loading/error states,
- `MediaRecorder` zachowuje się różnie między przeglądarkami, więc trzeba mieć fallback MIME,
- jeśli backend zwróci tylko `output[]`, a frontend nadal będzie czekał na `message`, UI przestanie działać od razu.

## Definition of Done

- frontend działa na `sessionId` z backendu,
- użytkownik może dodać plik lub obraz i zobaczyć go w composerze przed wysyłką,
- użytkownik może nagrać audio i wysłać je jako wiadomość,
- `chat/completions` dostaje `attachmentIds`, a nie surowe pliki,
- UI poprawnie renderuje odpowiedź backendu opartą o `output[]`.
