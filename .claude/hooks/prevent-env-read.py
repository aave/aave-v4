#!/usr/bin/env python3
"""
PreToolUse hook to prevent reading .env files
"""
import json
import sys

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    # If we can't parse input, allow the tool call
    sys.exit(0)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})

# Check if this is a Read or Grep tool call
if tool_name == "Read" or tool_name == "Grep":
    file_path = tool_input.get("file_path", "")
    path = tool_input.get("path", "")
    glob = tool_input.get("glob", "")

    # Block if trying to read .env file
    if ".env" in file_path or ".env" in path or ".env" in glob:
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "Reading .env files is not allowed for security reasons. Environment variables contain sensitive credentials.",
            }
        }
        print(json.dumps(output))
        sys.exit(2)


# Allow the tool call
sys.exit(0)