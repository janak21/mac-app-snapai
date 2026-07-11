import { mkdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { ConfigService } from "./config.js";
import { type UiGenerationDefaults, type UiProfile } from "../types.js";

interface ProfilesFileData {
  profiles: UiProfile[];
}

const SNAPAI_DIR = path.join(os.homedir(), ".snapai");
const PROFILES_PATH = path.join(SNAPAI_DIR, "profiles.json");

async function readProfilesData(): Promise<ProfilesFileData> {
  try {
    const raw = await readFile(PROFILES_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<ProfilesFileData>;
    if (!Array.isArray(parsed.profiles)) {
      return { profiles: [] };
    }
    return { profiles: parsed.profiles };
  } catch {
    return { profiles: [] };
  }
}

async function writeProfilesData(data: ProfilesFileData): Promise<void> {
  await mkdir(SNAPAI_DIR, { recursive: true });
  await writeFile(PROFILES_PATH, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

export class ProfilesService {
  static async list(): Promise<UiProfile[]> {
    const data = await readProfilesData();
    return [...data.profiles].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  static async getById(id: string): Promise<UiProfile | null> {
    const data = await readProfilesData();
    return data.profiles.find((profile) => profile.id === id) ?? null;
  }

  static async create(input: {
    name: string;
    description?: string;
    options?: UiGenerationDefaults;
  }): Promise<UiProfile> {
    const data = await readProfilesData();
    const now = new Date().toISOString();
    const profile: UiProfile = {
      id: randomUUID(),
      name: input.name,
      description: input.description,
      options: input.options ?? {},
      createdAt: now,
      updatedAt: now,
    };
    data.profiles.push(profile);
    await writeProfilesData(data);
    return profile;
  }

  static async update(
    id: string,
    updates: {
      name?: string;
      description?: string;
      options?: UiGenerationDefaults;
    }
  ): Promise<UiProfile | null> {
    const data = await readProfilesData();
    const index = data.profiles.findIndex((profile) => profile.id === id);
    if (index < 0) {
      return null;
    }

    const existing = data.profiles[index];
    const updated: UiProfile = {
      ...existing,
      ...updates,
      options: updates.options ? { ...existing.options, ...updates.options } : existing.options,
      updatedAt: new Date().toISOString(),
    };
    data.profiles[index] = updated;
    await writeProfilesData(data);
    return updated;
  }

  static async remove(id: string): Promise<boolean> {
    const data = await readProfilesData();
    const originalLength = data.profiles.length;
    data.profiles = data.profiles.filter((profile) => profile.id !== id);

    if (data.profiles.length === originalLength) {
      return false;
    }

    await writeProfilesData(data);

    const config = await ConfigService.getConfig();
    if (config.active_profile_id === id) {
      await ConfigService.set("active_profile_id", undefined);
    }
    return true;
  }

  static async useProfile(id: string): Promise<UiProfile | null> {
    const profile = await this.getById(id);
    if (!profile) {
      return null;
    }
    await ConfigService.set("active_profile_id", profile.id);
    return profile;
  }
}
