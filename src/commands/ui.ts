import { Command, Flags } from "@oclif/core";
import { spawn } from "node:child_process";
import { startUiServer } from "../ui/server.js";

function openUrl(url: string): void {
  const platform = process.platform;

  if (platform === "darwin") {
    spawn("open", [url], { detached: true, stdio: "ignore" }).unref();
    return;
  }

  if (platform === "win32") {
    spawn("cmd", ["/c", "start", "", url], { detached: true, stdio: "ignore" }).unref();
    return;
  }

  spawn("xdg-open", [url], { detached: true, stdio: "ignore" }).unref();
}

export default class UiCommand extends Command {
  static description = "Start SnapAI local UI MVP server";

  static flags = {
    port: Flags.integer({
      description: "Port for local UI server",
      default: 4173,
      min: 1,
      max: 65535,
    }),
    "no-open": Flags.boolean({
      description: "Do not open the browser automatically",
      default: false,
    }),
  };

  public async run(): Promise<void> {
    const { flags } = await this.parse(UiCommand);
    const server = await startUiServer({ port: flags.port });
    const url = `http://127.0.0.1:${server.port}`;

    this.log(`SnapAI UI running at ${url}`);
    this.log("Press Ctrl+C to stop.");

    if (!flags["no-open"]) {
      // Browser launch is best-effort and should not block server startup.
      try {
        openUrl(url);
      } catch {
        this.log("Could not auto-open browser. Open the URL manually.");
      }
    }

    await new Promise<void>((resolve) => {
      const shutdown = async (): Promise<void> => {
        process.off("SIGINT", onSignal);
        process.off("SIGTERM", onSignal);
        await server.close();
        resolve();
      };

      const onSignal = (): void => {
        void shutdown();
      };

      process.on("SIGINT", onSignal);
      process.on("SIGTERM", onSignal);
    });
  }
}
