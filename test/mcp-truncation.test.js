import { describe, it } from "node:test";
import assert from "node:assert";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const sdkSource = readFileSync(join(__dirname, "..", "sdk", "index.js"), "utf8");

describe("invokeToolResponseToToolResult (issue #1732)", () => {
  it("should use full content for textResultForLlm in the success path", () => {
    // The fix: in the success return object, textResultForLlm must use the
    // full filtered content (o) instead of the truncated content (a) so the
    // downstream large-output handler can detect oversized responses and save
    // them to a temp file.
    const fixedPattern =
      '{textResultForLlm:o||"",binaryResultsForLlm:s,resultType:"success",sessionLog:a,toolTelemetry:i,contents:r}';

    assert.ok(
      sdkSource.includes(fixedPattern),
      "Success path must use full content (o||\"\") for textResultForLlm, not the truncated value (a)"
    );
  });

  it("should NOT have the old buggy pattern that truncates success responses", () => {
    // The bug: textResultForLlm was set to the truncated value (a) on the
    // success path, which silently dropped content >10KB before the
    // large-output-to-file handler could intercept it.
    const buggyPattern =
      "{textResultForLlm:a,binaryResultsForLlm:s,resultType:\"success\",sessionLog:a,toolTelemetry:i,contents:r}";

    assert.ok(
      !sdkSource.includes(buggyPattern),
      "Success path must NOT use truncated content (a) for textResultForLlm — this causes silent data loss for MCP responses >10KB"
    );
  });

  it("should still use truncated content for textResultForLlm in the failure path", () => {
    // Error results can remain truncated since they are text-based error
    // messages that don't need the large-output-to-file mechanism.
    const failurePattern =
      "{textResultForLlm:a,resultType:\"failure\",error:a,sessionLog:a,toolTelemetry:i,contents:r}";

    assert.ok(
      sdkSource.includes(failurePattern),
      "Failure path should still use truncated content (a) for textResultForLlm"
    );
  });
});
