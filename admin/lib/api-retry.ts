const TRANSIENT_READ_STATUSES = new Set([408, 500, 502, 503, 504]);

export const READ_RETRY_DELAYS_MS = [250, 750] as const;

export function isIdempotentRead(method: string | undefined): boolean {
  const normalized = (method ?? "GET").toUpperCase();
  return normalized === "GET" || normalized === "HEAD";
}

export function shouldRetryRead(
  method: string | undefined,
  status: number
): boolean {
  return isIdempotentRead(method) && TRANSIENT_READ_STATUSES.has(status);
}
