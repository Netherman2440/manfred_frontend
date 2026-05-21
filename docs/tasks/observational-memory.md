# Observational Memory (FE)

## Problem Statement

Backend dorzucił mechanizm observational memory (skrót calej historii sesji do struktury obserwacji per (user, agent_name)). Endpoint `POST /api/v1/chat/sessions/{id}/summarize` istnieje i dziala SYNCHRONICZNIE — czeka, az obserwator wygeneruje update i zwraca wynik w jednym responsie. Frontend nie ma jeszcze:

- sposobu, zeby user mogl recznie wywolac podsumowanie ("podsumuj teraz"),
- (osobna sprawa, PR3) Shift+Enter w composerze daje nowa linie zamiast wysylki.

## Solution

W composerze chatu dodajemy slash-command `/summarize`. Po Enterze frontend wola endpoint i CZEKA na zwrotke. Composer pokazuje "recollecting" loading state (border breathing pulse + send button morphuje w spinner + dyskretny status row pod composerem z meta `~20s · do not refresh`). Po zwrotce pokazujemy SnackBar zgodnie z wynikiem:

- `200 success` → SnackBar success (zielony pasek) z preview obserwacji w italic block,
- `200 locked` → SnackBar locked (amber pasek) `Another observer is already running`,
- `200 below_threshold` → SnackBar locked-shaped (amber) `Not enough new context yet`,
- `200 error` → SnackBar error (red pasek) z `detail` w monospace + retry button,
- `204 no_unobserved` → cichy no-op, composer wraca do idle bez SnackBaru,
- `404 Not Found` → SnackBar error `Session not found`,
- `503 Service Unavailable` → SnackBar error `Summaries are disabled for this build` + ukrycie komendy `/summarize` z palette (sticky-disable per sessionId do reloadu aplikacji).

**WAZNE — co odpada vs. poprzedni plan:**

- **Brak item type `OBSERVATION`** w `ItemType` na BE (sa tylko MESSAGE, FUNCTION_CALL, FUNCTION_CALL_OUTPUT, REASONING). Wynik podsumowania NIE pojawia sie w transkripcie sesji — jest tylko efemeryczny SnackBar.
- **Brak SSE eventow `observation.*`** w strumieniu chatu. Eventy istnieja w BE event-busie (do langfuse/markdown loggerow) ale `_serialize_sse_event` ich nie obejmuje. Frontend ich nie sluсha i nie powinien.
- **Brak idle timera / auto-summarize**. Tylko reczne `/summarize`. (Decyzja z review: "wystarczy reczne summary".)

PR3 (niezalezny): w composerze Shift+Enter daje newline, plain Enter wysyla.

## User Stories

1. As a user prowadzacy dluga sesje, chce moc napisac `/summarize` w composerze, zeby recznie kazac agentowi zapisac nowe obserwacje.
2. As a user, chce zeby po wpisaniu `/` w composerze pojawila sie palette komend nad polem input, zebym widzial co moge zrobic.
3. As a user, chce zeby `/summarize` nie wysylal sie do LLM jako zwykla wiadomosc — to ma byc lokalna komenda, nie tekst dla modelu.
4. As a user, w trakcie podsumowywania chce widziec ze cos sie dzieje — pulsujacy border + spinner zamiast send buttona + dyskretny "recollecting" status row — i zeby pole bylo zablokowane.
5. As a user, oczekuje informacji "may take ~20s" w trakcie loadingu, zebym sie nie denerwowal ze app sie zawiesila.
6. As a user, po skonczonym podsumowaniu chce SnackBar z preview obserwacji (sukces) lub jasnym komunikatem dlaczego sie nie udalo (locked / error / dispatched off).
7. As a user, ktory dostal `204 no_unobserved`, nie chce widziec falszywej informacji o sukcesie — composer po prostu wraca do idle bez SnackBaru.
8. As a user, ktory wpisuje `/sum` (prefix) — chce zeby palette pokazala `/summarize` jako mozliwa komenda; Enter wtedy NIE wykonuje komendy, tylko wysyla zwykla wiadomosc (musi byc dokladnie `/<name>`).
9. As a user, ktory wpisze `/SUMMARIZE` zamiast `/summarize`, oczekuje ze i tak wystartuje — case-insensitive.
10. As a user, ktory wpisze `/summarize cos tam` (z argumentami) — komenda i tak startuje, argumenty sa ignorowane (komenda na razie ich nie obsluguje).
11. As a user piszacy wieloliniowa wiadomosc, chce uzyc Shift+Enter zeby zlamac linie zamiast wysylac (PR3).
12. As a developer, chce zeby slash-command registry byl rozszerzalny — dodanie nowej komendy = wpis w jeden plik, bez dotykania composera.

## Implementation Decisions

### Co odpada vs. poprzedni plan

- **Brak typu `OBSERVATION`** — NIE dodajemy `SessionSummarizingItem`, widgetu `SummarizingItem`, parsera w `sessions_dto.dart`, case'a w `conversation_list.dart`.
- **Brak handlerow SSE** `observation.started/success/failure` ani `reflection.*` — BE ich nie emituje przez API.
- **Brak idle timera** — caly `SessionIdleTimer`, sticky-disable per-sessionId-na-503, reset triggery (send / done / session change) — wszystko OOO.

### Kontrakt z backendem (faktyczny stan)

`POST /api/v1/chat/sessions/{session_id}/summarize`, request body pusty.

Synchroniczny — odpowiedz przychodzi po zakonczeniu obserwacji. Czas rzedu kilkunastu-kilkudziesiec sekund (model LLM observe). Brak streamingu czastkowego. FE musi miec dlugi HTTP timeout (≥60s; sprawdzic `ManfredApiClient` i podniesc lokalnie dla tej sciezki jesli za niski).

Odpowiedzi:

- `200 OK` z `{"status": "success", "observations_preview": "<do 200 znakow>"}` — sukces.
- `200 OK` z `{"status": "locked"}` — inny obserwator juz biezy dla pary (user, agent_name).
- `200 OK` z `{"status": "below_threshold", "detail": "<n> < <threshold>"}` — za malo nowych tokenow. Endpoint woła `observe_use_case` z `force=True`, wiec teoretycznie nie powinien sie pojawiac — FE obsluguje defensywnie.
- `200 OK` z `{"status": "error", "detail": "..."}` — observer wybuchl wewnetrznie.
- `204 No Content` — brak nieobserwowanych itemow.
- `404 Not Found` — sesja nie istnieje / niedostepna / agent_name niedostepny.
- `503 Service Unavailable` — `OBSERVATIONAL_MEMORY_ENABLED=false` lub `observe_use_case` nie wstrzyknieta.

Faktyczny shape z `app/api/v1/chat/api.py::summarize_session` + `app/services/chat_service.py::SummarizeResponse`:

```python
@dataclass(slots=True, frozen=True)
class SummarizeResponse:
    status: str  # "success" | "locked" | "no_unobserved" | "below_threshold" | "error"
    observations_preview: str | None = None
    detail: str | None = None
```

### Moduly do dodania / zmiany (FE)

- **`ChatRepository.summarize(sessionId) → SummarizeResult`**
  - W `lib/features/chat/data/chat_repository.dart` dodajemy metode do abstract i do `HttpChatRepository`.
  - `SummarizeResult` = sealed-class (Dart 3 patterns): `success(preview)`, `locked`, `belowThreshold(detail)`, `error(detail)`, `noUnobserved`, `notFound`, `featureDisabled`, `transportError`.
  - Mapowanie statusu HTTP + body.

- **Slash-command registry** (`lib/features/chat/domain/slash_command_registry.dart`)
  - Lista `SlashCommand { name, description, execute(sessionId, ref) → Future<void> }`.
  - Jedna komenda: `summarize` — name=`summarize`, description=`Fold the current conversation into long-term observations.` (placeholder, final wording dograсz w implementacji; ten sam string co w mockupie).
  - Registry jest filtrowane na podstawie sticky-disabled-set (zob. nizej).
  - Execute komendy `summarize`: ustaw loading state w composerze → wolanie `chatRepository.summarize` → schowanie loading state → SnackBar zgodnie z wynikiem.

- **Slash-command parsing + matching**
  - Detekcja: gdy `_controller.text.trimLeft()` zaczyna sie od `/`, palette otwarte.
  - Filter: `name.toLowerCase().startsWith(query.toLowerCase())` gdzie `query = text.trim().substring(1).split(RegExp(r'\s+')).first`.
  - Wykonanie komendy: text po `trim()` musi spelniac regex `^/([a-z][a-z0-9_-]*)(\s.*)?$` (case-insensitive na nazwie), pierwszy token musi byc dokladnie nazwa zarejestrowanej komendy. Argumenty (cokolwiek po pierwszej spacji) ignorowane na razie. **Prefix nie jest wystarczajacy** — `/sum` + Enter nie wykona `/summarize`, leci jako normalna wiadomosc; user musi zaakceptowac z palette (Enter na wyhighlightowanym item) lub dopisac do `/summarize`.
  - Faktycznie obie sciezki sa rownoznaczne: gdy user trafi Enter, sprawdzamy czy:
    - palette open + first item full-match → run command (Enter konsumowany), 
    - inaczej → traktuj jako normalna wiadomosc i `sendMessage`.

- **Slash-command palette UI** (komponent w `lib/ui/screens/chat_workspace/controls/`, np. `slash_command_palette.dart`)
  - Nakladka pozycjonowana nad composerem (`Stack` + `Positioned` lub `OverlayEntry` — zaleznie od layout-constraints; w mockupie zalozone ze siedzi w tym samym container co composer-row, nad polem input).
  - Struktura (z mockupa):
    - Header: `commands` (mono uppercase, letter-spacing 0.16em) + counter `<n> match` po prawej.
    - List: kazdy item ma 3 sekcje w grid: name (mono, `/` w accent-blue) | description (sans, text-secondary) | shortcut hint (`↵` lub `↑↓`).
    - Selected item: tlo `accent-blue-soft` + 2px lewy bar `accent-blue`.
    - Footer: keyboard hints `↑↓ navigate` · `↵ run` · `esc close` (mono 10px, text-muted, kbd-styled keys w `panel-alt`).
  - Klawiatura: `↑`/`↓` przesuwa selection (na razie tylko 1 wpis, no-op ale obsluga gotowa); `Enter` na zaznaczonej komendzie wywoluje ja i konsumuje keystroke; `Esc` zamyka palette zostawiajac text.
  - Otwarcie/zamkniecie: tekst zaczyna sie od `/` → open; usuniecie `/` lub Esc → close.

- **Composer loading state** (rozszerzenie `composer_state.dart` o flage / nullable command-name)
  - Pole input (`composer-field`): `border: accent-blue` + animacja `borderBreathe` (2.4s ease-in-out, opacity 0.55→0.9), inset shadow rgba(94,161,255,0.15→0.30), shimmer overlay 2.2s linear z transparentnego do `rgba(94,161,255,0.07)` i nazad. `readOnly: true` lub `enabled: false`.
  - Send button: identyczna geometria (38×38, button-radius=6), tlo `panel-overlay`, border `accent-blue`, w srodku `spinner` (14×14, border-top accent-blue, animacja `spin` 0.9s linear). Bez layout-jumpa.
  - Attach button: `opacity: 0.4`, pointer-events disabled.
  - "Recollecting" status row pod composerem:
    - Top: 14px margin + 14px padding-top + dashed top border (1px `border-subtle`).
    - Left: serif italic `~` glyph w accent-blue (Fraunces 17px) + label `Recollecting` (sans 13px text-secondary) + animowane 3 kropki (3×3px accent-blue, opacity 0.25→1, translateY 0→-1px, delay 0/0.2/0.4s, cykl 1.4s).
    - Right meta: mono 11px text-muted, `may take ~20s · do not refresh`.
  - **Inline copy do dogrania**: stringi w mockupie ("Recollecting", "may take ~20s · do not refresh") to placeholder. Final wording (PL vs EN, dokladne brzmienie) podejmiesz w implementacji — istniejacy UI jest mieszany (np. `Edytuj wiadomość` w user_message_item, reszta EN). Sugestia: spojnie z dominujacym EN, ale to twoja decyzja.

- **SnackBar variants** (uzyc `ScaffoldMessenger.of(context).showSnackBar`, ten sam pattern co `agent_editor_view.dart:270`)
  - Struktura wspolna: 2-column grid (body | actions); body ma 3px lewy pasek (kolor zgodny z wariantem) + headline (sans 14px bold + uppercase mono tag) + secondary text (sans 13px text-secondary) + opcjonalnie preview block / detail line.
  - Wariant `success`: lewy pasek `accent-green` + glow 16px; headline tag `summarized` (zielony) + `Observations saved`; secondary `Manfred folded <N> messages into long-term memory.`; preview block — italic serif (Fraunces 13.5px) cytat z `observations_preview`, lewy 2px `accent-green` bar, tlo `rgba(0,0,0,0.25)`; actions: `view` (no-op MVP lub no-show) + `dismiss`.
  - Wariant `locked`: lewy pasek `accent-amber`; headline tag `already running` + `Another observer has the lock`; secondary `A summary is in progress for <agent_name>. It will finish on its own — try again in a minute.`; actions: `dismiss`.
  - Wariant `below_threshold`: ten sam shape co `locked` ale tag `not enough yet` + `Not enough new context to summarize.`.
  - Wariant `error`: lewy pasek `accent-red`; headline tag `failed` + `Couldn't save observations`; secondary `The observer ran into an error. Your conversation is intact; nothing was written.`; detail row — monospace 11.5px text-muted (z `detail` z body); actions: `retry` (re-trigger summarize) + `dismiss`.
  - Wariant `404 not found`: lewy pasek `accent-red`; headline `Session not found`; actions: `dismiss`.
  - Wariant `503 disabled`: lewy pasek `accent-red`; headline `Summaries are disabled for this build`; effect: dodaj `summarize` do sticky-disabled-set.
  - **Wariant `204`**: zaden SnackBar.
  - Headline tag = maly mono badge z color-coded background (np. `rgba(118,211,155,0.13)` dla success).

- **Sticky-disable na 503**
  - `Set<String>` per `sessionId` w global state (np. `featureDisabledSummarizeProvider` jako `StateProvider<Set<String>>`).
  - Pierwszy 503 → wstaw `sessionId`. Registry filtruje `summarize` z palette dla sesji obecnej w secie. Reset dopiero przy reloadzie / restarcie.

- **Composer Shift+Enter fix (PR3 — wydzielony PR)**
  - W `composer_mock.dart` (linie ~162-190) `TextField.onSubmitted` zastapic `Focus.onKeyEvent`:
    - `KeyDownEvent` + `LogicalKeyboardKey.enter` + `HardwareKeyboard.instance.isShiftPressed` → `KeyEventResult.ignored` (TextField wstawi `\n`).
    - `KeyDownEvent` + `LogicalKeyboardKey.enter` BEZ shift → wywolaj `_send()` (lub command-dispatcher gdy palette open), `KeyEventResult.handled`.
  - `TextField`: `keyboardType: TextInputType.multiline`, `maxLines: null`, `textInputAction: TextInputAction.newline`, usun `onSubmitted`.
  - Na mobile Shift fizycznie nie istnieje — fallback default.

### Decyzja: synchroniczny await + transient UI state

Wybralismy spinner+toast zamiast persistent transcript item. Powody:

- BE jest synchroniczny — to zgodne z kontraktem.
- Nie potrzeba item type, parsera, widgetu, handlera SSE — duzo mniej kodu.
- Result jest efemeryczny — preview w SnackBar wystarcza; pelnych obserwacji user moze szukac w `.agent_data/.../memory.md` (BE).
- Reversible: jesli pozniej zechcemy persystowac w transkripcie, BE doda osobny item type i FE go doklei.

### Decyzja: aesthetic direction z mockupa

Mockup `docs/tasks/observational-memory-mockup.html` jest LOCKED jako referencja designu:

- Fonts: JetBrains Mono (komendy + meta), Switzer (body sans), Fraunces (display + preview cytat). Pierwsze dwa juz "musimy zaladowac" do Fluttera; sprawdzic czy app ma juz integracje `google_fonts` / Fontshare; jesli nie — uzyj `flutter_pub_get_local_font` lub najbliszego dostepnego.
- Color palette: `ManfredColors.*` (exact match w mockupie).
- "Recollecting" treatment dla loading state jest WAZNY — odrozniacie od standardowego spinnera. Border breathing + meta `~20s` to elementy ktore musza zostac.
- Snackbary kolorowymi paskami po lewej, struktura z tagiem + headline + secondary + opcjonalnie preview/detail.

## Testing Decisions

Testy weryfikuja zachowanie obserwowalne z perspektywy usera/integratora, nie wewnetrzne ksztalty obiektow.

### Co testujemy

- **`HttpChatRepository.summarize`** (data-layer):
  - 200 `success` → `SummarizeResult.success(preview)`.
  - 200 `locked` / `below_threshold` / `error` → odpowiednie warianty (preview/detail przeniesione).
  - 204 → `noUnobserved`.
  - 404 → `notFound`.
  - 503 → `featureDisabled`.
  - sieciowy blad / 500 / timeout → `transportError`.
  Uzyj wzorca z innych testow data-layer w `lib/features/` (sprawdzic obecne).

- **Slash-command matcher** (czysty unit-test bez UI):
  - `/summarize` → run.
  - `/SUMMARIZE`, `/Summarize` → run (case-insensitive).
  - `/summarize ` (trailing space) → run.
  - `/summarize foo bar` → run (args ignored).
  - `/sum` → no match, falls through to send-message.
  - `/unknown` → no match, falls through.
  - `summarize` (bez `/`) → no match.

- **`ComposerController` slash-command flow** (application-layer):
  - Wpisanie `/summarize` + Enter (palette open, item selected) → wywoluje `chatRepository.summarize`, NIE wywoluje `sendMessage`, czysci pole.
  - Loading state: po starcie komendy `composerState.runningCommand` = `summarize`, po zakonczeniu = `null`.
  - Wpisanie `/nieznane` + Enter → wywoluje `sendMessage` (fallback).
  - Wpisanie zwyklego tekstu + Enter → wywoluje `sendMessage`.
  - 503 result → sessionId trafia do `featureDisabledSummarizeProvider`.

- **Composer Shift+Enter (PR3, widgetowy)**:
  - Symuluj `KeyDownEvent(LogicalKeyboardKey.enter)` z i bez shift; sprawdz: pierwszy → `\n` w tekscie, send NIE wolane; drugi → send wolane, tekst wyczyszczony.

### Czego NIE testujemy

- Implementacji palette (overlay, layout) — wizualne dziala lub nie; pokrywa to manual QA.
- SnackBar UI — testujemy ze controller emituje toast event ze wlasciwym wariantem (jesli wydzielimy emitter); shape SnackBaru weryfikujemy manualnie.
- Animacji breathing/shimmer — to wizualne.

### Prior art

- `lib/features/sessions/data/sessions_repository.dart` + test (jesli istnieje) — wzorzec mapowania statusow HTTP na sealed-class result.
- `lib/features/chat/application/composer_controller.dart` — istniejace testy compositora (sprawdzic w `test/`), wzorzec rozszerzania stanu i triggerow.
- `lib/ui/screens/chat_workspace/agent_editor/agent_editor_view.dart:270` — wzorzec ScaffoldMessenger SnackBar (z `ManfredColors`).

## Out of Scope

- Item typu `OBSERVATION` w transkripcie sesji — BE go nie ma; nie dodajemy.
- Handler SSE `observation.*` / `reflection.*` — BE ich nie emituje przez API.
- Idle timer / auto-summarize — wycofane, tylko reczne.
- Side-panel z lista wszystkich obserwacji per sesja / per agent — przyszla feature.
- Per-agent (subagent) summarize z UI — endpoint dziala tylko dla root, FE nie eksponuje wyboru.
- Persistowanie informacji o ostatnim podsumowaniu w transkripcie — SnackBar wystarczy.
- Inne slash-komendy (np. `/clear`, `/help`) — registry jest przygotowany ale zawiera tylko `summarize`.
- Argumenty do `/summarize` (np. `/summarize last 10` lub `/summarize agent foo`) — ignorowane defensywnie, brak parsera.
- Offline / retry / queueing summarize po sieciowym bledzie (poza single-shot retry buttonem w SnackBar).
- `/api/v1/config` z flaga feature-disabled — na razie 503 jest sygnalem; FE nie czyta osobnej konfiguracji na boot.
- Globalny toast/notification service — uzywamy najprostszego `ScaffoldMessenger`.
- Final wording wszystkich UI stringow — copy z mockupa to placeholder, dokladne brzmienie ustalisz w PR.

## Further Notes

- Spec nadpisuje poprzednie iteracje (gdzie byl `SessionSummarizingItem`, SSE handler, item type OBSERVATION, idle timer). Powod: przeglad BE wykazal ze endpoint jest synchroniczny i nie ma typu OBSERVATION; user dodatkowo wycofal idle-timer wymagajac tylko recznego summary.
- BE moze w przyszlosci dodac item type i emitowac SSE — spec jest neutralnie odwracalny.
- Mockup `docs/tasks/observational-memory-mockup.html` jest referencja designu — patrz tam dla dokladnych proporcji, kolorow i micro-interactions.
- Timeout HTTP klienta musi byc dlugi (≥60s) — sprawdzic `ManfredApiClient` default i podniesc lokalnie dla tej sciezki.
- Sticky-disable jest in-memory per session (`Set<String>` w `StateProvider`). Restart aplikacji = swiezy try.

## Handoff

Done:
- Zdefiniowano FE-kontrakt dla observational memory: slash-command + sync await + SnackBar.
- Wycofano typ OBSERVATION, SSE handler, idle timer — niepotrzebne lub odrzucone.
- Zatwierdzono direction designu (mockup HTML w `docs/tasks/observational-memory-mockup.html`).
- Sprecyzowano regule matchowania slash-komendy (case-insensitive, first-token-exact, args ignored).

Next role:
- Frontend developer implementujacy PR2: `ChatRepository.summarize` + registry + palette + loading state + SnackBary + sticky-disable + testy.
- Frontend developer (niezaleznie) implementujacy PR3: Shift+Enter fix.

Open / soft:
- Final wording inline copy ("Recollecting", "may take ~20s · do not refresh", SnackBary) — PL vs EN do decyzji w PR.
- Strategia ladowania fontow JetBrains Mono / Switzer / Fraunces do Fluttera — `google_fonts` paczka czy bundled assets, do weryfikacji.
