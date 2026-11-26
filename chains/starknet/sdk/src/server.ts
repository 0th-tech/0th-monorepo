async function post<T>(url: string, input: unknown): Promise<T> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input),
  }).catch(() => {
    throw new Error(`cannot reach ${url}`);
  });
  if (!res.ok) {
    // An unknown route answers with an empty body, a failed one with { error }
    const body: unknown = await res.json().catch(() => undefined);
    const error =
      typeof body === "object" && body !== null && "error" in body
        ? String(body.error)
        : `${res.status} ${res.statusText}`;
    throw new Error(`${url} failed: ${error}`);
  }
  return (await res.json()) as T;
}

export const prove = async (serverUrl: string, input: Record<string, string>) =>
  (await post<{ proof: string[] }>(`${serverUrl}/prove`, input)).proof;
