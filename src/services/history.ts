import { mkdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { type UiHistoryEntry } from "../types.js";

interface HistoryFileData {
  entries: UiHistoryEntry[];
}

const SNAPAI_DIR = path.join(os.homedir(), ".snapai");
const HISTORY_PATH = path.join(SNAPAI_DIR, "history.json");

async function readHistoryData(): Promise<HistoryFileData> {
  try {
    const raw = await readFile(HISTORY_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<HistoryFileData>;
    if (!Array.isArray(parsed.entries)) {
      return { entries: [] };
    }
    return { entries: parsed.entries };
  } catch {
    return { entries: [] };
  }
}

async function writeHistoryData(data: HistoryFileData): Promise<void> {
  await mkdir(SNAPAI_DIR, { recursive: true });
  await writeFile(HISTORY_PATH, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

export class HistoryService {
  static async list(): Promise<UiHistoryEntry[]> {
    const data = await readHistoryData();
    return [...data.entries].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  static async append(entry: Omit<UiHistoryEntry, "id" | "createdAt">): Promise<UiHistoryEntry> {
    const data = await readHistoryData();
    const created: UiHistoryEntry = {
      id: randomUUID(),
      createdAt: new Date().toISOString(),
      ...entry,
    };
    data.entries.push(created);
    await writeHistoryData(data);
    return created;
  }

  static async remove(id: string): Promise<boolean> {
    const data = await readHistoryData();
    const originalLength = data.entries.length;
    data.entries = data.entries.filter((entry) => entry.id !== id);
    if (data.entries.length === originalLength) {
      return false;
    }
    await writeHistoryData(data);
    return true;
  }

  static async clear(): Promise<void> {
    await writeHistoryData({ entries: [] });
  }
}
