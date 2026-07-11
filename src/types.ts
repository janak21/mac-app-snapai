export interface ConfigData {
  openai_api_key?: string;
  google_api_key?: string;
  default_output_path?: string;
  defaults?: UiGenerationDefaults;
  active_profile_id?: string;
  ux_flags?: Record<string, boolean>;
  ui_settings?: UiSettings;
}

export interface IconGenerationOptions {
  prompt: string;
  output?: string;
  quality?: 'auto' | 'standard' | 'hd' | 'high' | 'medium' | 'low';
  background?: 'transparent' | 'opaque' | 'auto';
  outputFormat?: 'png' | 'jpeg' | 'webp';
  /**
   * CLI model alias.
   * Internally, SnapAI maps this to the provider's underlying model ID.
   */
  model?: 'gpt-1' | 'gpt-1.5' | 'gpt-image-2' | 'gpt';
  numImages?: number;
  moderation?: 'low' | 'auto';
  rawPrompt?: boolean;
  apiKey?: string;
}

export interface OpenAIResponse {
  data: Array<{
    url: string;
    revised_prompt?: string;
  }>;
}

export type UiModelAlias = "gpt-1.5" | "gpt-1" | "gpt" | "banana";
export type UiProvider = "openai" | "banana";
export type UiOpenAIQuality = "auto" | "high" | "medium" | "low" | "hd" | "standard";
export type UiBananaQuality = "1k" | "2k" | "4k";
export type UiQuality = UiOpenAIQuality | UiBananaQuality;

export interface UiGenerationDefaults {
  output?: string;
  fileName?: string;
  model?: UiModelAlias;
  quality?: UiQuality;
  background?: "transparent" | "opaque" | "auto";
  outputFormat?: "png" | "jpeg" | "webp";
  moderation?: "low" | "auto";
  rawPrompt?: boolean;
  style?: string;
  useIconWords?: boolean;
  pro?: boolean;
  n?: number;
}

export interface UiSettings {
  autoOpenBrowser?: boolean;
  costWarningThreshold?: number;
}

export interface UiProfile {
  id: string;
  name: string;
  description?: string;
  options: UiGenerationDefaults;
  createdAt: string;
  updatedAt: string;
}

export interface UiHistoryEntry {
  id: string;
  createdAt: string;
  prompt: string;
  finalPrompt: string;
  provider: UiProvider;
  model: UiModelAlias;
  options: UiGenerationDefaults;
  outputPaths: string[];
  profileId?: string;
}
