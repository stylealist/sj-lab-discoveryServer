#!/usr/bin/env bash
file=$(jq -r '.tool_input.file_path // empty')

case "$file" in
  */target/*|*\\target\\*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"target/ 은 빌드 산출물입니다. src/main/resources 등 소스를 수정한 뒤 ./mvnw clean package 로 다시 빌드하세요."}}'
    ;;
esac
