import { Command, Flags } from "@oclif/core";
import { createInterface, type Interface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { ConfigService } from "../services/config.js";
import { ProfilesService } from "../services/profiles.js";
import { GenerationService, type GenerationResult } from "../services/generation.js";
import { HistoryService } from "../services/history.js";
import { ValidationService } from "../utils/validation.js";
import { type UiGenerationDefaults, type UiModelAlias, type UiProfile } from "../types.js";

type PostAction = "rerun" | "edit-prompt" | "switch-profile" | "history" | "quit";

interface ProfileContext {
  activeProfile: UiProfile | null;
  selectedProfile: UiProfile | null;
  profiles: UiProfile[];
}

export default class StudioCommand extends Command {
  static description = "Interactive TUI flow for generating icons with prompt/profile/options.";

  static flags = {
    prompt: Flags.string({
      char: "p",
      description: "Initial prompt (skips first prompt question)",
    }),
    model: Flags.string({
      char: "m",
      description: 'Initial model override: "gpt-1.5", "gpt-1", "gpt", or "banana"',
      options: ["gpt-1.5", "gpt-1", "gpt", "banana"],
    }),
    profile: Flags.string({
      description: "Initial profile id or profile name",
    }),
  };

  public async run(): Promise<void> {
    const { flags } = await this.parse(StudioCommand);
    const rl = createInterface({ input, output });

    try {
      this.log("SnapAI Studio");
      this.log("Interactive icon generation with profile-aware defaults.\n");

      const prompt = await this.askRequiredPrompt(rl, flags.prompt);
      let selectedProfileId = await this.resolveInitialProfileId(flags.profile);
      if (flags.profile && !selectedProfileId) {
        this.log(`Profile not found: "${flags.profile}".`);
      }

      if (!selectedProfileId) {
        selectedProfileId = await this.askProfileSelection(rl, undefined);
      }

      const seededOverrides: UiGenerationDefaults = {};
      if (flags.model) {
        seededOverrides.model = flags.model as UiModelAlias;
      }

      const overrides = await this.askOverrides(rl, seededOverrides);

      let currentPrompt = prompt;

      while (true) {
        const profileContext = await this.resolveProfiles(selectedProfileId);
        if (selectedProfileId && !profileContext.selectedProfile) {
          this.log(`Selected profile not found: ${selectedProfileId}. Continuing without explicit profile.`);
          selectedProfileId = undefined;
        }

        const mergedOptions = this.mergeOptions(profileContext, overrides);
        const profileIdForHistory = profileContext.selectedProfile?.id ?? profileContext.activeProfile?.id;

        const confirmed = await this.confirmGeneration(rl, {
          prompt: currentPrompt,
          profileContext,
          mergedOptions,
        });

        if (confirmed) {
          await this.generateAndPersist(currentPrompt, mergedOptions, profileIdForHistory);
        } else {
          this.log("Generation canceled.");
        }

        while (true) {
          const action = await this.askPostAction(rl);
          if (action === "rerun") {
            break;
          }

          if (action === "edit-prompt") {
            currentPrompt = await this.askRequiredPrompt(rl, currentPrompt);
            break;
          }

          if (action === "switch-profile") {
            selectedProfileId = await this.askProfileSelection(rl, selectedProfileId);
            break;
          }

          if (action === "history") {
            await this.printRecentHistory();
            continue;
          }

          return;
        }
      }
    } finally {
      rl.close();
    }
  }

  private async askRequiredPrompt(rl: Interface, current?: string): Promise<string> {
    while (true) {
      const suffix = current ? ` [current: ${current}]` : "";
      const raw = await rl.question(`Prompt (required)${suffix}: `);
      const value = raw.trim() || current;

      if (!value) {
        this.log("Prompt is required.");
        continue;
      }

      const error = ValidationService.validatePrompt(value);
      if (error) {
        this.log(`Invalid prompt: ${error}`);
        continue;
      }

      return value;
    }
  }

  private async askProfileSelection(rl: Interface, currentProfileId?: string): Promise<string | undefined> {
    const profiles = await ProfilesService.list();
    if (profiles.length === 0) {
      this.log("No saved profiles found. Using config defaults only.");
      return undefined;
    }

    this.log("\nOptional profile override:");
    this.log("0) None");

    for (const [index, profile] of profiles.entries()) {
      const marker = profile.id === currentProfileId ? " (current)" : "";
      this.log(`${index + 1}) ${profile.name}${marker}`);
    }

    while (true) {
      const answer = (await rl.question("Select profile number (Enter for none): ")).trim();
      if (!answer) {
        return undefined;
      }

      const parsed = Number.parseInt(answer, 10);
      if (!Number.isInteger(parsed) || parsed < 0 || parsed > profiles.length) {
        this.log(`Invalid selection. Enter a number between 0 and ${profiles.length}.`);
        continue;
      }

      if (parsed === 0) {
        return undefined;
      }

      return profiles[parsed - 1]?.id;
    }
  }

  private async askOverrides(rl: Interface, initial: UiGenerationDefaults = {}): Promise<UiGenerationDefaults> {
    const configure = await this.askYesNo(rl, "Configure option overrides now?", false);
    if (!configure) {
      return { ...initial };
    }

    const overrides: UiGenerationDefaults = { ...initial };

    const style = await this.askOptionalString(rl, "style");
    if (style !== undefined) {
      overrides.style = style;
    }

    const model = await this.askOptionalEnum(rl, "model", ["gpt-1.5", "gpt-1", "gpt", "banana"]);
    if (model !== undefined) {
      overrides.model = model;
    }

    const n = await this.askOptionalInt(rl, "n", 1, 10);
    if (n !== undefined) {
      overrides.n = n;
    }

    const quality = await this.askOptionalEnum(rl, "quality", [
      "auto",
      "standard",
      "hd",
      "high",
      "medium",
      "low",
      "1k",
      "2k",
      "4k",
    ]);
    if (quality !== undefined) {
      overrides.quality = quality;
    }

    const background = await this.askOptionalEnum(rl, "background", ["transparent", "opaque", "auto"]);
    if (background !== undefined) {
      overrides.background = background;
    }

    const outputFormat = await this.askOptionalEnum(rl, "outputFormat", ["png", "jpeg", "webp"]);
    if (outputFormat !== undefined) {
      overrides.outputFormat = outputFormat;
    }

    const outputValue = await this.askOptionalString(rl, "output directory");
    if (outputValue !== undefined) {
      const outputError = ValidationService.validateOutputPath(outputValue);
      if (outputError) {
        this.log(`Invalid output path: ${outputError}. Ignoring override.`);
      } else {
        overrides.output = outputValue;
      }
    }

    const pro = await this.askOptionalBoolean(rl, "pro");
    if (pro !== undefined) {
      overrides.pro = pro;
    }

    const rawPrompt = await this.askOptionalBoolean(rl, "rawPrompt");
    if (rawPrompt !== undefined) {
      overrides.rawPrompt = rawPrompt;
    }

    const useIconWords = await this.askOptionalBoolean(rl, "useIconWords");
    if (useIconWords !== undefined) {
      overrides.useIconWords = useIconWords;
    }

    return overrides;
  }

  private async resolveInitialProfileId(profileInput?: string): Promise<string | undefined> {
    if (!profileInput) {
      return undefined;
    }

    const value = profileInput.trim();
    if (!value) {
      return undefined;
    }

    const profiles = await ProfilesService.list();
    const byId = profiles.find((profile) => profile.id === value);
    if (byId) {
      return byId.id;
    }

    const normalized = value.toLowerCase();
    const byName = profiles.find((profile) => profile.name.toLowerCase() === normalized);
    return byName?.id;
  }

  private async resolveProfiles(selectedProfileId?: string): Promise<ProfileContext> {
    const [config, profiles] = await Promise.all([ConfigService.getConfig(), ProfilesService.list()]);

    const activeProfile =
      typeof config.active_profile_id === "string"
        ? profiles.find((profile) => profile.id === config.active_profile_id) ?? null
        : null;

    const selectedProfile =
      typeof selectedProfileId === "string"
        ? profiles.find((profile) => profile.id === selectedProfileId) ?? null
        : null;

    return { activeProfile, selectedProfile, profiles };
  }

  private mergeOptions(profileContext: ProfileContext, overrides: UiGenerationDefaults): UiGenerationDefaults {
    return {
      ...(profileContext.activeProfile?.options ?? {}),
      ...(profileContext.selectedProfile?.options ?? {}),
      ...overrides,
    };
  }

  private async confirmGeneration(
    rl: Interface,
    input: {
      prompt: string;
      profileContext: ProfileContext;
      mergedOptions: UiGenerationDefaults;
    }
  ): Promise<boolean> {
    const config = await ConfigService.getConfig();
    const finalMerged: UiGenerationDefaults = {
      ...(config.defaults ?? {}),
      ...input.mergedOptions,
    };

    this.log("\nGeneration plan:");
    this.log(`Prompt: ${input.prompt}`);
    this.log(`Active profile: ${input.profileContext.activeProfile?.name ?? "none"}`);
    this.log(`Selected profile: ${input.profileContext.selectedProfile?.name ?? "none"}`);
    this.log(`Resolved options: ${this.formatOptions(finalMerged)}`);

    return this.askYesNo(rl, "Generate now?", true);
  }

  private async generateAndPersist(
    prompt: string,
    mergedOptions: UiGenerationDefaults,
    profileId?: string
  ): Promise<void> {
    const config = await ConfigService.getConfig();
    const options: UiGenerationDefaults = {
      ...(config.defaults ?? {}),
      ...mergedOptions,
    };

    try {
      this.log("\nGenerating...");
      const result = await GenerationService.generate({ prompt, options });

      await this.appendHistory(prompt, result, profileId);

      this.log(`Done. Provider: ${result.provider}, model: ${result.model}`);
      this.log("Saved output paths:");
      for (const outputPath of result.outputPaths) {
        this.log(` - ${outputPath}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      this.log(`Generation failed: ${message}`);
    }
  }

  private async appendHistory(prompt: string, result: GenerationResult, profileId?: string): Promise<void> {
    await HistoryService.append({
      prompt,
      finalPrompt: result.finalPrompt,
      provider: result.provider,
      model: result.model,
      options: result.options,
      outputPaths: result.outputPaths,
      profileId,
    });
  }

  private async printRecentHistory(): Promise<void> {
    const entries = await HistoryService.list();
    if (entries.length === 0) {
      this.log("\nNo history entries yet.");
      return;
    }

    this.log("\nRecent history:");
    for (const [index, entry] of entries.slice(0, 10).entries()) {
      this.log(`${index + 1}. ${new Date(entry.createdAt).toLocaleString()} | ${entry.model} | ${entry.prompt}`);
      this.log(`   ${entry.outputPaths.join(", ")}`);
    }
  }

  private async askPostAction(rl: Interface): Promise<PostAction> {
    this.log("\nNext action:");
    this.log("1) Rerun same");
    this.log("2) Edit prompt");
    this.log("3) Switch profile");
    this.log("4) View recent history");
    this.log("5) Quit");

    while (true) {
      const answer = (await rl.question("Choose 1-5: ")).trim();
      if (answer === "1") return "rerun";
      if (answer === "2") return "edit-prompt";
      if (answer === "3") return "switch-profile";
      if (answer === "4") return "history";
      if (answer === "5") return "quit";
      this.log("Invalid choice. Enter 1, 2, 3, 4, or 5.");
    }
  }

  private async askYesNo(rl: Interface, question: string, defaultValue: boolean): Promise<boolean> {
    const hint = defaultValue ? "Y/n" : "y/N";

    while (true) {
      const answer = (await rl.question(`${question} (${hint}): `)).trim().toLowerCase();
      if (!answer) return defaultValue;
      if (answer === "y" || answer === "yes") return true;
      if (answer === "n" || answer === "no") return false;
      this.log("Please answer y/yes or n/no.");
    }
  }

  private async askOptionalString(rl: Interface, fieldName: string): Promise<string | undefined> {
    const answer = await rl.question(`${fieldName} override (Enter to skip): `);
    const trimmed = answer.trim();
    if (!trimmed) {
      return undefined;
    }
    return trimmed;
  }

  private async askOptionalEnum<T extends string>(
    rl: Interface,
    fieldName: string,
    allowedValues: readonly T[]
  ): Promise<T | undefined> {
    const allowedText = allowedValues.join("|");

    while (true) {
      const answer = (await rl.question(`${fieldName} override [${allowedText}] (Enter to skip): `)).trim();
      if (!answer) {
        return undefined;
      }

      const normalized = answer.toLowerCase() as T;
      if (allowedValues.includes(normalized)) {
        return normalized;
      }

      this.log(`Invalid ${fieldName}. Valid values: ${allowedText}`);
    }
  }

  private async askOptionalInt(
    rl: Interface,
    fieldName: string,
    min: number,
    max: number
  ): Promise<number | undefined> {
    while (true) {
      const answer = (await rl.question(`${fieldName} override [${min}-${max}] (Enter to skip): `)).trim();
      if (!answer) {
        return undefined;
      }

      const parsed = Number.parseInt(answer, 10);
      if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
        this.log(`Invalid ${fieldName}. Must be an integer between ${min} and ${max}.`);
        continue;
      }

      return parsed;
    }
  }

  private async askOptionalBoolean(rl: Interface, fieldName: string): Promise<boolean | undefined> {
    while (true) {
      const answer = (await rl.question(`${fieldName} override [true|false] (Enter to skip): `)).trim().toLowerCase();
      if (!answer) {
        return undefined;
      }

      if (answer === "true" || answer === "t" || answer === "yes" || answer === "y" || answer === "1") {
        return true;
      }

      if (answer === "false" || answer === "f" || answer === "no" || answer === "n" || answer === "0") {
        return false;
      }

      this.log(`Invalid ${fieldName}. Enter true/false.`);
    }
  }

  private formatOptions(options: UiGenerationDefaults): string {
    const entries = Object.entries(options).filter(([, value]) => value !== undefined);
    if (entries.length === 0) {
      return "(none)";
    }

    return entries
      .map(([key, value]) => `${key}=${typeof value === "string" ? value : String(value)}`)
      .join(", ");
  }
}
