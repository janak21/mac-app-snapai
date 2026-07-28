import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { access, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ConfigService } from "../services/config.js";
import { buildFinalIconPrompt } from "../utils/icon-prompt.js";
import { GenerationService } from "../services/generation.js";
import { ProfilesService } from "../services/profiles.js";
import { HistoryService } from "../services/history.js";
import { ValidationService } from "../utils/validation.js";
import { type ConfigData, type UiGenerationDefaults } from "../types.js";

export interface StartUiServerOptions {
  port: number;
  authToken?: string;
}

export interface UiServerHandle {
  port: number;
  close: () => Promise<void>;
}

interface PromptPreviewPayload {
  prompt?: unknown;
  rawPrompt?: unknown;
  style?: unknown;
  useIconWords?: unknown;
}

interface ConfigUpdatePayload {
  openai_api_key?: unknown;
  google_api_key?: unknown;
  default_output_path?: unknown;
  defaults?: unknown;
  active_profile_id?: unknown;
  ux_flags?: unknown;
  ui_settings?: unknown;
}

interface GeneratePayload {
  prompt?: unknown;
  options?: unknown;
  profileId?: unknown;
  credentials?: unknown;
}

interface GenerationCredentials {
  openai?: string;
  google?: string;
}

interface CreateProfilePayload {
  name?: unknown;
  description?: unknown;
  options?: unknown;
}

interface UpdateProfilePayload {
  name?: unknown;
  description?: unknown;
  options?: unknown;
}

class HttpError extends Error {
  statusCode: number;

  constructor(statusCode: number, message: string) {
    super(message);
    this.statusCode = statusCode;
  }
}

function sendJson(res: ServerResponse, statusCode: number, body: unknown): void {
  res.statusCode = statusCode;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify(body));
}

function sendText(res: ServerResponse, statusCode: number, body: string): void {
  res.statusCode = statusCode;
  res.setHeader("content-type", "text/plain; charset=utf-8");
  res.end(body);
}

function sendHtml(res: ServerResponse, html: string): void {
  res.statusCode = 200;
  res.setHeader("content-type", "text/html; charset=utf-8");
  res.end(html);
}

function getMimeType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === ".html") return "text/html; charset=utf-8";
  if (ext === ".js") return "text/javascript; charset=utf-8";
  if (ext === ".css") return "text/css; charset=utf-8";
  if (ext === ".json") return "application/json; charset=utf-8";
  if (ext === ".svg") return "image/svg+xml";
  if (ext === ".png") return "image/png";
  if (ext === ".jpg" || ext === ".jpeg") return "image/jpeg";
  if (ext === ".webp") return "image/webp";
  if (ext === ".ico") return "image/x-icon";
  if (ext === ".txt") return "text/plain; charset=utf-8";
  return "application/octet-stream";
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function readBody(req: IncomingMessage, maxBytes = 1024 * 1024): Promise<string> {
  const chunks: Buffer[] = [];
  let total = 0;

  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    total += buffer.length;
    if (total > maxBytes) {
      throw new HttpError(413, "Request body too large");
    }
    chunks.push(buffer);
  }

  return Buffer.concat(chunks).toString("utf8");
}

async function parseJsonBody<T>(req: IncomingMessage): Promise<T> {
  const rawBody = await readBody(req);
  if (!rawBody.trim()) {
    return {} as T;
  }

  try {
    return JSON.parse(rawBody) as T;
  } catch {
    throw new HttpError(400, "Invalid JSON body");
  }
}

function assertPlainObject(value: unknown, fieldName: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpError(400, `Field "${fieldName}" must be an object.`);
  }
  return value as Record<string, unknown>;
}

function normalizeOptionsInput(value: unknown, fieldName: string): UiGenerationDefaults {
  if (value === undefined) {
    return {};
  }
  const object = assertPlainObject(value, fieldName);
  return object as UiGenerationDefaults;
}

function normalizeCredentialsInput(value: unknown): GenerationCredentials | undefined {
  if (value === undefined) {
    return undefined;
  }

  const object = assertPlainObject(value, "credentials");
  const credentials: GenerationCredentials = {};

  for (const [key, field] of [["openai", "credentials.openai"], ["google", "credentials.google"]] as const) {
    const raw = object[key];
    if (raw === undefined) {
      continue;
    }
    if (typeof raw !== "string") {
      throw new HttpError(400, `Field "${field}" must be a string.`);
    }
    const trimmed = raw.trim();
    if (trimmed) {
      credentials[key] = trimmed;
    }
  }

  return credentials;
}

function validateProfileName(name: unknown): string {
  if (typeof name !== "string" || name.trim().length === 0) {
    throw new HttpError(400, 'Field "name" is required and must be a non-empty string.');
  }
  const trimmed = name.trim();
  if (trimmed.length > 80) {
    throw new HttpError(400, 'Field "name" must be 80 characters or fewer.');
  }
  return trimmed;
}

function validatePrompt(prompt: unknown): string {
  if (typeof prompt !== "string") {
    throw new HttpError(400, 'Field "prompt" is required and must be a non-empty string.');
  }
  const value = prompt.trim();
  const error = ValidationService.validatePrompt(value);
  if (error) {
    throw new HttpError(400, error);
  }
  return value;
}

function validateConfigUpdates(payload: ConfigUpdatePayload): Partial<ConfigData> {
  const updates: Partial<ConfigData> = {};

  if (payload.openai_api_key !== undefined) {
    const apiKey = payload.openai_api_key;
    if (typeof apiKey !== "string") {
      throw new HttpError(400, 'Field "openai_api_key" must be a string.');
    }
    updates.openai_api_key = apiKey.trim() || undefined;
  }

  if (payload.google_api_key !== undefined) {
    const apiKey = payload.google_api_key;
    if (typeof apiKey !== "string") {
      throw new HttpError(400, 'Field "google_api_key" must be a string.');
    }
    updates.google_api_key = apiKey.trim() || undefined;
  }

  if (payload.default_output_path !== undefined) {
    if (typeof payload.default_output_path !== "string" || payload.default_output_path.trim().length === 0) {
      throw new HttpError(400, 'Field "default_output_path" must be a non-empty string.');
    }
    updates.default_output_path = payload.default_output_path.trim();
  }

  if (payload.defaults !== undefined) {
    updates.defaults = normalizeOptionsInput(payload.defaults, "defaults");
  }

  if (payload.active_profile_id !== undefined) {
    if (payload.active_profile_id !== null && typeof payload.active_profile_id !== "string") {
      throw new HttpError(400, 'Field "active_profile_id" must be a string or null.');
    }
    updates.active_profile_id = payload.active_profile_id ?? undefined;
  }

  if (payload.ux_flags !== undefined) {
    const uxFlags = assertPlainObject(payload.ux_flags, "ux_flags");
    for (const [key, value] of Object.entries(uxFlags)) {
      if (typeof value !== "boolean") {
        throw new HttpError(400, `Field "ux_flags.${key}" must be a boolean.`);
      }
    }
    updates.ux_flags = uxFlags as Record<string, boolean>;
  }

  if (payload.ui_settings !== undefined) {
    const uiSettings = assertPlainObject(payload.ui_settings, "ui_settings");
    if (uiSettings.autoOpenBrowser !== undefined && typeof uiSettings.autoOpenBrowser !== "boolean") {
      throw new HttpError(400, 'Field "ui_settings.autoOpenBrowser" must be a boolean.');
    }
    if (
      uiSettings.costWarningThreshold !== undefined &&
      (!Number.isInteger(uiSettings.costWarningThreshold) || (uiSettings.costWarningThreshold as number) < 1)
    ) {
      throw new HttpError(400, 'Field "ui_settings.costWarningThreshold" must be an integer >= 1.');
    }
    updates.ui_settings = uiSettings as ConfigData["ui_settings"];
  }

  if (Object.keys(updates).length === 0) {
    throw new HttpError(400, "No valid config fields provided.");
  }

  return updates;
}

function toUiConfig(config: ConfigData, activeProfile: unknown): Record<string, unknown> {
  const { openai_api_key, google_api_key, ...rest } = config;
  return {
    ...rest,
    defaults: config.defaults ?? {},
    openai_api_key_configured: Boolean(openai_api_key),
    google_api_key_configured: Boolean(google_api_key),
    active_profile: activeProfile,
  };
}

function tryParseJson(input: string): unknown {
  try {
    return JSON.parse(input);
  } catch {
    return undefined;
  }
}

function getRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value === "object" && value !== null && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function getProviderErrorShape(error: unknown): Record<string, unknown> | null {
  const root = getRecord(error);
  if (!root) return null;

  const directError = getRecord(root.error);
  if (directError) return directError;

  if (typeof root.message === "string") {
    const parsed = tryParseJson(root.message);
    const parsedObj = getRecord(parsed);
    if (parsedObj) {
      const parsedError = getRecord(parsedObj.error);
      if (parsedError) return parsedError;
      return parsedObj;
    }
  }

  return root;
}

function extractRetryDelaySeconds(text: string): string | undefined {
  const retryInMatch = text.match(/retry in ([\d.]+)\s*s/i);
  if (retryInMatch?.[1]) return retryInMatch[1];
  const retryDelayMatch = text.match(/"retryDelay"\s*:\s*"(\d+)s"/i);
  if (retryDelayMatch?.[1]) return retryDelayMatch[1];
  return undefined;
}

function normalizeUnexpectedError(error: unknown): {
  statusCode: number;
  payload: { message: string; code?: number; status?: string };
} {
  const providerError = getProviderErrorShape(error);
  const codeRaw = providerError?.code;
  const statusRaw = providerError?.status;
  const messageRaw = providerError?.message;

  const code = typeof codeRaw === "number" ? codeRaw : undefined;
  const status = typeof statusRaw === "string" ? statusRaw : undefined;
  const message = typeof messageRaw === "string" ? messageRaw : error instanceof Error ? error.message : "Internal server error";

  const isQuotaRelated =
    code === 429 ||
    status === "RESOURCE_EXHAUSTED" ||
    /quota|rate[- ]?limit|exceeded your current quota|insufficient[_ ]quota/i.test(message);

  if (isQuotaRelated) {
    const retrySeconds = extractRetryDelaySeconds(message);
    const retryHint = retrySeconds ? ` Retry in about ${retrySeconds} seconds.` : "";
    return {
      statusCode: 429,
      payload: {
        message:
          "Quota exceeded or rate limit reached for this model/provider. Please add credits or increase limits, then retry." +
          retryHint,
        code: code ?? 429,
        status: status ?? "RESOURCE_EXHAUSTED",
      },
    };
  }

  const cleanMessage = String(message).split("\n")[0].trim() || "Internal server error";
  return {
    statusCode: code && code >= 400 && code < 600 ? code : 500,
    payload: {
      message: cleanMessage,
      ...(code ? { code } : {}),
      ...(status ? { status } : {}),
    },
  };
}

function renderHomePage(): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>SnapAI Local UI MVP</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f3f7fb;
        --card: #ffffff;
        --text: #132035;
        --muted: #4f6078;
        --ok: #118a44;
        --error: #b0212a;
        font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: radial-gradient(circle at top, #ffffff 0%, var(--bg) 65%);
        color: var(--text);
      }
      main {
        width: min(680px, calc(100vw - 2rem));
        background: var(--card);
        border: 1px solid #dde4ee;
        border-radius: 16px;
        padding: 2rem;
        box-shadow: 0 10px 24px rgba(12, 24, 40, 0.08);
      }
      h1 {
        margin: 0 0 0.75rem;
        font-size: 1.6rem;
      }
      p {
        margin: 0;
        line-height: 1.55;
        color: var(--muted);
      }
      .status {
        margin-top: 1.5rem;
        padding: 0.9rem 1rem;
        border-radius: 10px;
        border: 1px solid #d6e0ee;
        font-weight: 600;
      }
      .status--loading { color: var(--muted); }
      .status--ok { color: var(--ok); border-color: #b7ddc4; background: #f2fbf5; }
      .status--error { color: var(--error); border-color: #efc3c8; background: #fff4f5; }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        background: #eef4ff;
        color: #0b4fb4;
        border-radius: 6px;
        padding: 0.15rem 0.4rem;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>SnapAI local UI MVP</h1>
      <p>
        The local API is ready. Use <code>/api/health</code>, <code>/api/config</code>,
        <code>/api/profiles</code>, <code>/api/history</code>, and <code>/api/generate</code>.
      </p>
      <div id="health" class="status status--loading">Checking API health...</div>
    </main>

    <script>
      const healthEl = document.getElementById("health");
      fetch("/api/health")
        .then((res) => {
          if (!res.ok) throw new Error("Unexpected status " + res.status);
          return res.json();
        })
        .then((payload) => {
          healthEl.textContent = payload.ok ? "API health: OK" : "API health: Unexpected payload";
          healthEl.className = payload.ok ? "status status--ok" : "status status--error";
        })
        .catch((err) => {
          healthEl.textContent = "API health check failed: " + err.message;
          healthEl.className = "status status--error";
        });
    </script>
  </body>
</html>`;
}

async function resolveStaticDirectory(): Promise<string | null> {
  const currentFileDir = path.dirname(fileURLToPath(import.meta.url));
  const candidates = [
    path.resolve(process.cwd(), "src/ui/static"),
    path.resolve(process.cwd(), "dist/ui/static"),
    path.resolve(currentFileDir, "static"),
  ];

  for (const candidate of candidates) {
    if (await pathExists(candidate)) {
      return candidate;
    }
  }
  return null;
}

async function serveStatic(
  res: ServerResponse,
  staticDir: string,
  requestPathname: string
): Promise<boolean> {
  const staticPathname = requestPathname.startsWith("/static/")
    ? requestPathname.replace(/^\/static/, "")
    : requestPathname;
  const normalizedPath = staticPathname === "/" ? "/index.html" : staticPathname;
  const decodedPath = decodeURIComponent(normalizedPath);
  const unsafeFilePath = path.join(staticDir, decodedPath);
  const safeRoot = path.resolve(staticDir);
  const safeFilePath = path.resolve(unsafeFilePath);

  if (!safeFilePath.startsWith(`${safeRoot}${path.sep}`) && safeFilePath !== safeRoot) {
    sendText(res, 403, "Forbidden");
    return true;
  }

  try {
    const fileStats = await stat(safeFilePath);
    if (!fileStats.isFile()) {
      return false;
    }
    const fileBuffer = await readFile(safeFilePath);
    res.statusCode = 200;
    res.setHeader("content-type", getMimeType(safeFilePath));
    res.end(fileBuffer);
    return true;
  } catch {
    return false;
  }
}

export async function startUiServer(options: StartUiServerOptions): Promise<UiServerHandle> {
  const { port, authToken } = options;
  const staticDir = await resolveStaticDirectory();

  const server = createServer(async (req, res) => {
    try {
      const method = req.method ?? "GET";
      const requestUrl = new URL(req.url ?? "/", "http://127.0.0.1");
      const pathname = requestUrl.pathname;

      if (authToken && pathname.startsWith("/api/")) {
        const authorization = req.headers.authorization;
        if (authorization !== `Bearer ${authToken}`) {
          sendJson(res, 401, { error: "Unauthorized" });
          return;
        }
      }

      if ((method === "GET" || method === "HEAD") && !pathname.startsWith("/api/") && staticDir) {
        const served = await serveStatic(res, staticDir, pathname);
        if (served) {
          return;
        }
      }

      if (method === "GET" && pathname === "/") {
        sendHtml(res, renderHomePage());
        return;
      }

      if (method === "GET" && pathname === "/api/health") {
        sendJson(res, 200, { ok: true, ts: new Date().toISOString() });
        return;
      }

      if (method === "GET" && pathname === "/api/config") {
        const [config, profiles] = await Promise.all([ConfigService.getConfig(), ProfilesService.list()]);
        const activeProfile =
          typeof config.active_profile_id === "string"
            ? profiles.find((profile) => profile.id === config.active_profile_id) ?? null
            : null;

        sendJson(res, 200, toUiConfig(config, activeProfile));
        return;
      }

      if (method === "POST" && pathname === "/api/config") {
        const body = await parseJsonBody<ConfigUpdatePayload>(req);
        const updates = validateConfigUpdates(body);
        await ConfigService.setConfig(updates);
        const [config, profiles] = await Promise.all([ConfigService.getConfig(), ProfilesService.list()]);
        const activeProfile =
          typeof config.active_profile_id === "string"
            ? profiles.find((profile) => profile.id === config.active_profile_id) ?? null
            : null;
        sendJson(res, 200, toUiConfig(config, activeProfile));
        return;
      }

      if (method === "GET" && pathname === "/api/profiles") {
        const [profiles, config] = await Promise.all([ProfilesService.list(), ConfigService.getConfig()]);
        sendJson(res, 200, {
          profiles,
          active_profile_id: config.active_profile_id ?? null,
        });
        return;
      }

      if (method === "POST" && pathname === "/api/profiles") {
        const body = await parseJsonBody<CreateProfilePayload>(req);
        const profile = await ProfilesService.create({
          name: validateProfileName(body.name),
          description: typeof body.description === "string" ? body.description.trim() || undefined : undefined,
          options: normalizeOptionsInput(body.options, "options"),
        });
        sendJson(res, 201, profile);
        return;
      }

      const profilePatchMatch = pathname.match(/^\/api\/profiles\/([^/]+)$/);
      if (profilePatchMatch && method === "PATCH") {
        const profileId = decodeURIComponent(profilePatchMatch[1]);
        const body = await parseJsonBody<UpdateProfilePayload>(req);
        const updates: { name?: string; description?: string; options?: UiGenerationDefaults } = {};

        if (body.name !== undefined) {
          updates.name = validateProfileName(body.name);
        }
        if (body.description !== undefined) {
          if (body.description !== null && typeof body.description !== "string") {
            throw new HttpError(400, 'Field "description" must be a string or null.');
          }
          updates.description =
            typeof body.description === "string" ? body.description.trim() || undefined : undefined;
        }
        if (body.options !== undefined) {
          updates.options = normalizeOptionsInput(body.options, "options");
        }
        if (Object.keys(updates).length === 0) {
          throw new HttpError(400, "No valid profile fields provided.");
        }

        const profile = await ProfilesService.update(profileId, updates);
        if (!profile) {
          sendJson(res, 404, { error: "Profile not found" });
          return;
        }
        sendJson(res, 200, profile);
        return;
      }

      if (profilePatchMatch && method === "DELETE") {
        const profileId = decodeURIComponent(profilePatchMatch[1]);
        const removed = await ProfilesService.remove(profileId);
        if (!removed) {
          sendJson(res, 404, { error: "Profile not found" });
          return;
        }
        sendJson(res, 200, { ok: true });
        return;
      }

      const profileUseMatch = pathname.match(/^\/api\/profiles\/([^/]+)\/use$/);
      if (profileUseMatch && method === "POST") {
        const profileId = decodeURIComponent(profileUseMatch[1]);
        const profile = await ProfilesService.useProfile(profileId);
        if (!profile) {
          sendJson(res, 404, { error: "Profile not found" });
          return;
        }
        sendJson(res, 200, { ok: true, profile });
        return;
      }

      if (method === "GET" && pathname === "/api/history") {
        const entries = await HistoryService.list();
        sendJson(res, 200, { history: entries });
        return;
      }

      if (method === "DELETE" && pathname === "/api/history") {
        await HistoryService.clear();
        sendJson(res, 200, { ok: true });
        return;
      }

      const historyDeleteMatch = pathname.match(/^\/api\/history\/([^/]+)$/);
      if (historyDeleteMatch && method === "DELETE") {
        const historyId = decodeURIComponent(historyDeleteMatch[1]);
        const removed = await HistoryService.remove(historyId);
        if (!removed) {
          sendJson(res, 404, { error: "History item not found" });
          return;
        }
        sendJson(res, 200, { ok: true });
        return;
      }

      if (method === "POST" && pathname === "/api/prompt-preview") {
        const body = await parseJsonBody<PromptPreviewPayload>(req);
        const prompt = validatePrompt(body.prompt);

        const finalPrompt = buildFinalIconPrompt({
          prompt,
          rawPrompt: Boolean(body.rawPrompt),
          style: typeof body.style === "string" ? body.style : undefined,
          useIconWords: Boolean(body.useIconWords),
        });

        sendJson(res, 200, { finalPrompt });
        return;
      }

      if (method === "POST" && pathname === "/api/generate") {
        const body = await parseJsonBody<GeneratePayload>(req);
        const prompt = validatePrompt(body.prompt);

        if (body.profileId !== undefined && typeof body.profileId !== "string") {
          throw new HttpError(400, 'Field "profileId" must be a string when provided.');
        }

        const [config, profiles] = await Promise.all([ConfigService.getConfig(), ProfilesService.list()]);

        const explicitProfile =
          typeof body.profileId === "string"
            ? profiles.find((profile) => profile.id === body.profileId) ?? null
            : null;
        if (typeof body.profileId === "string" && !explicitProfile) {
          sendJson(res, 404, { error: "Profile not found" });
          return;
        }

        const credentials = normalizeCredentialsInput(body.credentials);

        const activeProfile =
          typeof config.active_profile_id === "string"
            ? profiles.find((profile) => profile.id === config.active_profile_id) ?? null
            : null;
        const requestOptions = normalizeOptionsInput(body.options, "options");
        const mergedOptions: UiGenerationDefaults = {
          ...(config.defaults ?? {}),
          ...(activeProfile?.options ?? {}),
          ...(explicitProfile?.options ?? {}),
          ...requestOptions,
        };

        const result = await GenerationService.generate({
          prompt,
          options: mergedOptions,
          credentials,
        });

        const historyEntry = await HistoryService.append({
          prompt,
          finalPrompt: result.finalPrompt,
          provider: result.provider,
          model: result.model,
          options: result.options,
          outputPaths: result.outputPaths,
          profileId: explicitProfile?.id ?? activeProfile?.id,
        });

        sendJson(res, 200, {
          ok: true,
          result: {
            ...result,
            fileUrls: result.outputPaths.map((outputPath) => ({
              path: outputPath,
              url: `/api/files/${encodeURIComponent(outputPath)}`,
            })),
          },
          history: historyEntry,
        });
        return;
      }

      const fileMatch = pathname.match(/^\/api\/files\/(.+)$/);
      if (fileMatch && method === "GET") {
        const absolutePath = path.resolve(decodeURIComponent(fileMatch[1]));
        const history = await HistoryService.list();
        const isKnownOutput = history.some((entry) =>
          entry.outputPaths.some((outputPath) => path.resolve(outputPath) === absolutePath)
        );
        if (!isKnownOutput) {
          sendJson(res, 404, { error: "File not found" });
          return;
        }
        const fileStats = await stat(absolutePath);
        if (!fileStats.isFile()) {
          sendJson(res, 404, { error: "File not found" });
          return;
        }

        const fileBuffer = await readFile(absolutePath);
        res.statusCode = 200;
        res.setHeader("content-type", getMimeType(absolutePath));
        res.end(fileBuffer);
        return;
      }

      sendJson(res, 404, { error: "Not found" });
    } catch (error) {
      if (error instanceof HttpError) {
        sendJson(res, error.statusCode, { error: error.message });
        return;
      }

      const normalized = normalizeUnexpectedError(error);
      sendJson(res, normalized.statusCode, { error: normalized.payload });
    }
  });

  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", () => {
      server.off("error", reject);
      resolve();
    });
  });

  return {
    port,
    close: () =>
      new Promise<void>((resolve, reject) => {
        server.close((error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        });
      }),
  };
}
