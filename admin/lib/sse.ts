export interface SseFrame {
  event: string;
  data: string;
  id?: string;
  retry?: number;
}

export function parseSseFrame(raw: string): SseFrame | null {
  let event = "message";
  let id: string | undefined;
  let retry: number | undefined;
  const data: string[] = [];

  for (const line of raw.split("\n")) {
    if (!line || line.startsWith(":")) continue;
    const separator = line.indexOf(":");
    const field = separator < 0 ? line : line.slice(0, separator);
    let value = separator < 0 ? "" : line.slice(separator + 1);
    if (value.startsWith(" ")) value = value.slice(1);

    if (field === "event") event = value;
    if (field === "data") data.push(value);
    if (field === "id" && !value.includes("\0")) id = value;
    if (field === "retry" && /^\d+$/.test(value)) retry = Number(value);
  }

  if (data.length === 0 && id === undefined && retry === undefined) return null;
  return { event, data: data.join("\n"), id, retry };
}

export function drainSseFrames(buffer: string): {
  frames: SseFrame[];
  rest: string;
} {
  const normalized = buffer.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  const parts = normalized.split("\n\n");
  const rest = parts.pop() ?? "";
  const frames = parts
    .map(parseSseFrame)
    .filter((frame): frame is SseFrame => frame !== null);
  return { frames, rest };
}
