import * as z from "zod/v4";

function formatIssues(error: z.ZodError): string {
  return error.issues
    .map((issue) => {
      const path = issue.path.length > 0 ? issue.path.join(".") : "(root)";
      return `${path}: ${issue.message}`;
    })
    .join("; ");
}

export function parseJsonWithSchema<TSchema extends z.ZodTypeAny>(
  text: string,
  schema: TSchema,
  label: string,
): z.infer<TSchema> {
  let parsed: unknown;

  try {
    parsed = JSON.parse(text);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`${label} emitted invalid JSON: ${message}`);
  }

  const result = schema.safeParse(parsed);

  if (!result.success) {
    throw new Error(`${label} emitted unexpected JSON shape: ${formatIssues(result.error)}`);
  }

  return result.data;
}
