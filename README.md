# Manfred Chat Frontend

Lekki frontend React + Vite dla backendu Python wystawiajacego `POST /api/v1/chat`.

## Co jest gotowe

- pelny ekran czatu z responsywnym layoutem
- lokalny stan rozmowy i trwaly `thread_id`
- obsluga `loading`, anulowania requestu i bledow API
- render odpowiedzi asystenta przez `Markdown` z `@copilotkit/react-ui`
- prosty dev proxy do backendu

## Dlaczego nie gotowy `CopilotChat`

CopilotKitowy `CopilotChat` zaklada ich runtime / AG-UI. Twoj backend wystawia teraz prosty REST:

```json
{
  "message": "string",
  "thread_id": "string"
}
```

Dlatego najszybszy setup to:

- wykorzystac CopilotKit w warstwie renderingu i wzorcow headless UI
- zostawic transport pod Twoj aktualny endpoint bez dodatkowego adaptera runtime

Jesli pozniej backend przejdzie na runtime CopilotKit albo streaming, ten frontend da sie rozszerzyc bez wyrzucania calego UI.

## Uruchomienie

1. Skopiuj `.env.example` do `.env.local`.
2. Ustaw `VITE_API_PROXY_TARGET`, jesli backend dziala na innym hoscie niz frontend dev server.
3. Zainstaluj zaleznosci:

```bash
npm install
```

4. Odpal dev server:

```bash
npm run dev
```

Frontend wysyla requesty na:

- `/api/v1/chat` przy same-origin lub z proxy
- `${VITE_API_BASE_URL}/api/v1/chat`, jesli ustawisz `VITE_API_BASE_URL`

## Build

```bash
npm run build
```
