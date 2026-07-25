/** Join class names — falsy values skipped. */
export function cn(
  ...parts: ReadonlyArray<string | undefined | false | null>
): string {
  return parts.filter(Boolean).join(" ");
}
