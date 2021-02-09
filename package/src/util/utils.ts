import { CmdResult, runCmd } from "./cmd.ts";
import { Logger } from "./logger.ts";

// Read an environment variable
export function getEnv(name: string, defaultValue?: string) {
  const value = Deno.env.get(name);
  if (!value) {
    if (defaultValue === undefined) {
    throw new Error("Missing environment variable: " + name);
    } else {
      return defaultValue;
    }
  } else {
    return value;
  }
}

export async function download(src: string, dest: string): Promise<void> {
  const response = await fetch(src);
  const data = await response.blob();

  const buffer = await data.arrayBuffer();
  const contents = new Uint8Array(buffer);

  const file = await Deno.create(dest);
  await Deno.writeAll(file, contents);
  Deno.close(file.rid);
}

export async function unzip(zipFile: string, dest: string, log: Logger): Promise<CmdResult> {
  if (Deno.build.os === "windows") {
    return runCmd("PowerShell", ["Expand-Archive", "-Path", zipFile, "-DestinationPath", dest], log);
  } else {
    return runCmd("unzip", [zipFile, "-d", dest], log);
  }
}

