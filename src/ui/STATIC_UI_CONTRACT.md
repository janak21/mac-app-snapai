# Static UI contract notes

These notes describe assumptions used by `src/ui/static/app.js` and `src/ui/static/index.html`.

## Static file serving
- The UI expects the server to serve:
  - `/static/index.html`
  - `/static/app.css`
  - `/static/app.js`

## API endpoints
- The UI calls:
  - `GET /api/health`
  - `GET /api/config`
  - `POST /api/config`
  - `GET /api/profiles`
  - `POST /api/profiles`
  - `PATCH /api/profiles/:id`
  - `DELETE /api/profiles/:id`
  - `POST /api/profiles/:id/use`
  - `GET /api/history`
  - `DELETE /api/history`
  - `POST /api/prompt-preview`
  - `POST /api/generate`

## Image previews
- The UI attempts to render thumbnails when a returned image path is directly web-accessible.
- It expects URL-like values (for example `https://...`, `/files/...`, or other root-relative URL paths).
- If the backend returns filesystem-only paths, the UI shows metadata/path text without thumbnail preview.
