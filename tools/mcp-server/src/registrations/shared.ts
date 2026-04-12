export function jsonText(data: unknown): string {
  return JSON.stringify(data, null, 2);
}

export function successResult<T extends object>(structuredContent: T) {
  return {
    content: [{ type: "text" as const, text: jsonText(structuredContent) }],
    structuredContent: structuredContent as T & Record<string, unknown>,
  };
}

export function errorResult(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);

  return {
    isError: true,
    content: [{ type: "text" as const, text: message }],
  };
}

export async function withResourceError<T>(callback: () => Promise<T>): Promise<T> {
  try {
    return await callback();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(message, { cause: error });
  }
}
