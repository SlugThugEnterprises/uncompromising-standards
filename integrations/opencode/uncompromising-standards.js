const HOOK_SCRIPT = "__UNCOMPROMISING_STANDARDS_ROOT__/hooks/pre-write.sh"
const SUPPORTED_TOOLS = new Set(["write", "edit", "multiedit"])

function getArgs(input, output) {
  return output?.args ?? input?.args ?? {}
}

function getFilePath(args) {
  return args.filePath ?? args.path ?? args.file ?? ""
}

function getString(args, keys) {
  for (const key of keys) {
    if (typeof args?.[key] === "string") {
      return args[key]
    }
  }
  return ""
}

function applyExactEdit(content, edit) {
  const oldString = getString(edit, ["oldString", "old_string", "oldText", "old_text"])
  const newString = getString(edit, ["newString", "new_string", "newText", "new_text"])

  if (!oldString) {
    return null
  }

  const index = content.indexOf(oldString)
  if (index === -1) {
    return null
  }

  return `${content.slice(0, index)}${newString}${content.slice(index + oldString.length)}`
}

async function computeCandidateContent(tool, args) {
  if (tool === "write") {
    return getString(args, ["content", "contents", "text"]) || null
  }

  const filePath = getFilePath(args)
  if (!filePath) {
    return null
  }

  let content = await Bun.file(filePath).text().catch(() => "")

  if (tool === "edit") {
    return applyExactEdit(content, args)
  }

  if (tool === "multiedit") {
    const edits = Array.isArray(args.edits)
      ? args.edits
      : Array.isArray(args.changes)
        ? args.changes
        : []

    if (edits.length === 0) {
      return null
    }

    for (const edit of edits) {
      const nextContent = applyExactEdit(content, edit)
      if (nextContent === null) {
        return null
      }
      content = nextContent
    }

    return content
  }

  return null
}

function extractReason(stdoutText, stderrText) {
  for (const source of [stderrText, stdoutText]) {
    if (!source || !source.trim()) {
      continue
    }

    try {
      const parsed = JSON.parse(source)
      const hookReason = parsed?.hookSpecificOutput?.permissionDecisionReason
      if (hookReason) {
        return hookReason
      }
      if (parsed?.reason) {
        return parsed.reason
      }
    } catch {
      // Fall back to raw text below.
    }
  }

  return stderrText.trim() || stdoutText.trim() || "Code standards check failed"
}

async function runHook(filePath, content) {
  const payload = JSON.stringify({
    tool_name: "Write",
    tool_input: {
      file_path: filePath,
      content,
    },
  })

  const process = Bun.spawn(["/bin/bash", HOOK_SCRIPT], {
    stdin: payload,
    stdout: "pipe",
    stderr: "pipe",
  })

  const [stdoutText, stderrText, exitCode] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ])

  if (exitCode === 0) {
    return
  }

  throw new Error(extractReason(stdoutText, stderrText))
}

export const UncompromisingStandardsPlugin = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (!SUPPORTED_TOOLS.has(input.tool)) {
        return
      }

      const args = getArgs(input, output)
      const filePath = getFilePath(args)
      if (!filePath) {
        return
      }

      const content = await computeCandidateContent(input.tool, args)
      if (content === null) {
        return
      }

      await runHook(filePath, content)
    },
  }
}
