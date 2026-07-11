import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { ConfigService } from "./config.js";
import { GeminiService } from "./gemini.js";
import { OpenAIService } from "./openai.js";
import { buildFinalIconPrompt } from "../utils/icon-prompt.js";
import { ValidationService } from "../utils/validation.js";
import { type UiGenerationDefaults, type UiModelAlias, type UiProvider } from "../types.js";

export interface GenerationRequest {
  prompt: string;
  options?: UiGenerationDefaults;
}

export interface GenerationResult {
  provider: UiProvider;
  model: UiModelAlias;
  finalPrompt: string;
  options: UiGenerationDefaults;
  outputPaths: string[];
}

interface ResolvedOpenAIOptions {
  output: string;
  model: "gpt-1" | "gpt-1.5";
  quality: "auto" | "high" | "medium" | "low";
  background: "transparent" | "opaque" | "auto";
  outputFormat: "png" | "jpeg" | "webp";
  moderation: "low" | "auto";
  n: number;
}

interface ResolvedBananaOptions {
  output: string;
  quality: "1k" | "2k" | "4k";
  pro: boolean;
  n: number;
}

function normalizeModel(model?: string): UiModelAlias {
  const normalized = String(model ?? "gpt-1.5").trim().toLowerCase();
  if (normalized === "gpt") return "gpt-1.5";
  if (normalized === "gpt-1" || normalized === "gpt-1.5" || normalized === "banana") {
    return normalized;
  }
  throw new Error('Invalid model. Valid values: "gpt-1.5", "gpt-1", "gpt", "banana".');
}

function resolveProvider(model: UiModelAlias): UiProvider {
  return model === "banana" ? "banana" : "openai";
}

function resolveImageCount(input: unknown): number {
  const fallback = 1;
  if (typeof input !== "number" || !Number.isInteger(input)) {
    return fallback;
  }
  if (input < 1 || input > 10) {
    throw new Error('Invalid "n". Must be an integer between 1 and 10.');
  }
  return input;
}

function resolveOpenAIQuality(input: unknown): "auto" | "high" | "medium" | "low" {
  const normalized = String(input ?? "auto").trim().toLowerCase();
  if (normalized === "hd") return "high";
  if (normalized === "standard") return "medium";
  if (normalized === "auto" || normalized === "high" || normalized === "medium" || normalized === "low") {
    return normalized;
  }
  throw new Error('Invalid "quality" for OpenAI. Valid values: auto, high, medium, low, hd, standard.');
}

function resolveBananaQuality(input: unknown): "1k" | "2k" | "4k" {
  const normalized = String(input ?? "auto").trim().toLowerCase();
  if (normalized === "auto") return "1k";
  if (normalized === "1k" || normalized === "2k" || normalized === "4k") {
    return normalized;
  }
  throw new Error('Invalid "quality" for banana. Valid values: 1k, 2k, 4k, auto.');
}

function resolveBackground(input: unknown): "transparent" | "opaque" | "auto" {
  const normalized = String(input ?? "auto").trim().toLowerCase();
  if (normalized === "transparent" || normalized === "opaque" || normalized === "auto") {
    return normalized;
  }
  throw new Error('Invalid "background". Valid values: transparent, opaque, auto.');
}

function resolveOutputFormat(input: unknown): "png" | "jpeg" | "webp" {
  const normalized = String(input ?? "png").trim().toLowerCase();
  if (normalized === "png" || normalized === "jpeg" || normalized === "webp") {
    return normalized;
  }
  throw new Error('Invalid "outputFormat". Valid values: png, jpeg, webp.');
}

function resolveModeration(input: unknown): "low" | "auto" {
  const normalized = String(input ?? "auto").trim().toLowerCase();
  if (normalized === "low" || normalized === "auto") {
    return normalized;
  }
  throw new Error('Invalid "moderation". Valid values: low, auto.');
}

function resolveOutputPath(input: unknown, fallback?: string): string {
  const output = typeof input === "string" && input.trim().length > 0 ? input.trim() : fallback ?? "./assets";
  const error = ValidationService.validateOutputPath(output);
  if (error) {
    throw new Error(error);
  }
  return output;
}

async function saveBase64Images(
  base64DataArray: string[],
  outputDir: string,
  outputFormat: "png" | "jpeg" | "webp",
  fileNameBase?: string
): Promise<string[]> {
  await mkdir(outputDir, { recursive: true });
  const outputPaths: string[] = [];
  const timestamp = Date.now();

  for (let i = 0; i < base64DataArray.length; i += 1) {
    const base64Data = base64DataArray[i];
    const filename =
      fileNameBase && base64DataArray.length === 1
        ? `${fileNameBase}.${outputFormat}`
        : fileNameBase && base64DataArray.length > 1
          ? `${fileNameBase}-${i + 1}.${outputFormat}`
          : base64DataArray.length === 1
            ? `icon-${timestamp}.${outputFormat}`
            : `icon-${timestamp}-${i + 1}.${outputFormat}`;
    const outputPath = path.join(outputDir, filename);
    const buffer = Buffer.from(base64Data, "base64");
    await writeFile(outputPath, buffer);
    outputPaths.push(outputPath);
  }

  return outputPaths;
}

async function saveBinaryImages(
  images: Array<{ base64: string; extension: string }>,
  outputDir: string,
  fileNameBase?: string
): Promise<string[]> {
  await mkdir(outputDir, { recursive: true });
  const outputPaths: string[] = [];
  const timestamp = Date.now();

  for (let i = 0; i < images.length; i += 1) {
    const { base64, extension } = images[i];
    const filename =
      fileNameBase && images.length === 1
        ? `${fileNameBase}.${extension}`
        : fileNameBase && images.length > 1
          ? `${fileNameBase}-${i + 1}.${extension}`
          : images.length === 1
            ? `icon-${timestamp}.${extension}`
            : `icon-${timestamp}-${i + 1}.${extension}`;
    const outputPath = path.join(outputDir, filename);
    const buffer = Buffer.from(base64, "base64");
    await writeFile(outputPath, buffer);
    outputPaths.push(outputPath);
  }

  return outputPaths;
}

function sanitizeFileNameBase(input: unknown): string | undefined {
  if (typeof input !== "string") return undefined;
  const trimmed = input.trim();
  if (!trimmed) return undefined;

  const withoutExtension = trimmed.replace(/\.[a-z0-9]{2,5}$/i, "");
  const normalized = withoutExtension
    .toLowerCase()
    .replace(/[^a-z0-9-_]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);

  return normalized || undefined;
}

export class GenerationService {
  static async generate(request: GenerationRequest): Promise<GenerationResult> {
    const promptError = ValidationService.validatePrompt(request.prompt);
    if (promptError) {
      throw new Error(promptError);
    }

    const config = await ConfigService.getConfig();
    const options = request.options ?? {};
    const fileNameBase = sanitizeFileNameBase(options.fileName);
    const model = normalizeModel(options.model);
    const provider = resolveProvider(model);
    const finalPrompt = buildFinalIconPrompt({
      prompt: request.prompt,
      rawPrompt: Boolean(options.rawPrompt),
      style: typeof options.style === "string" ? options.style : undefined,
      useIconWords: Boolean(options.useIconWords),
    });

    const sharedOutput = resolveOutputPath(options.output, config.default_output_path);

    if (provider === "banana") {
      const resolved = this.resolveBananaOptions(options, sharedOutput);
      const images = await GeminiService.generateBananaImages({
        prompt: finalPrompt,
        pro: resolved.pro,
        n: resolved.pro ? resolved.n : 1,
        quality: resolved.quality,
      });
      const outputPaths = await saveBinaryImages(images, resolved.output, fileNameBase);
      return {
        provider,
        model,
        finalPrompt,
        outputPaths,
        options: {
          ...options,
          output: resolved.output,
          fileName: fileNameBase,
          quality: resolved.quality,
          n: resolved.pro ? resolved.n : 1,
          pro: resolved.pro,
          model,
        },
      };
    }

    const resolved = this.resolveOpenAIOptions(options, model, sharedOutput);
    const imageBase64Array = await OpenAIService.generateIcon({
      prompt: finalPrompt,
      output: resolved.output,
      model: resolved.model,
      quality: resolved.quality,
      background: resolved.background,
      outputFormat: resolved.outputFormat,
      numImages: resolved.n,
      moderation: resolved.moderation,
      rawPrompt: true,
    });
    const outputPaths = await saveBase64Images(
      imageBase64Array,
      resolved.output,
      resolved.outputFormat,
      fileNameBase
    );
    return {
      provider,
      model,
      finalPrompt,
      outputPaths,
      options: {
        ...options,
        output: resolved.output,
        fileName: fileNameBase,
        quality: resolved.quality,
        background: resolved.background,
        outputFormat: resolved.outputFormat,
        moderation: resolved.moderation,
        n: resolved.n,
        model,
      },
    };
  }

  private static resolveOpenAIOptions(
    options: UiGenerationDefaults,
    model: UiModelAlias,
    output: string
  ): ResolvedOpenAIOptions {
    if (model !== "gpt-1" && model !== "gpt-1.5") {
      throw new Error('Invalid OpenAI model. Valid values: "gpt-1", "gpt-1.5", "gpt".');
    }

    return {
      output,
      model,
      quality: resolveOpenAIQuality(options.quality),
      background: resolveBackground(options.background),
      outputFormat: resolveOutputFormat(options.outputFormat),
      moderation: resolveModeration(options.moderation),
      n: resolveImageCount(options.n),
    };
  }

  private static resolveBananaOptions(
    options: UiGenerationDefaults,
    output: string
  ): ResolvedBananaOptions {
    const pro = Boolean(options.pro);
    const quality = resolveBananaQuality(options.quality);
    const n = resolveImageCount(options.n);

    if (!pro && n !== 1) {
      throw new Error('Banana normal mode only supports "n" = 1.');
    }
    if (!pro && quality !== "1k") {
      throw new Error('Banana normal mode only supports "quality" = "1k".');
    }

    return {
      output,
      quality,
      pro,
      n,
    };
  }
}
