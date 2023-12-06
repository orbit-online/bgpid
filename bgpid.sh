#!/usr/bin/env bash
# shellcheck disable=2128

bg_add() {
  [[ -n $BG_PIDS ]] || BG_PIDS=()
  BG_PIDS+=("$1")
  bg_block || return $?
}

bg_run() {
  bg_block || return $?
  "$@" & BG_PIDS+=($!)
}

bg_waitany() {
  [[ -n $BG_PIDS ]] || return 0
  if ${BG_FAIL:-true}; then
    local pid found=false bg_new_pids ret=0
    while true; do
      bg_new_pids=()
      for pid in "${BG_PIDS[@]}"; do
        if ! $found && ! kill -0 "$pid" 2>/dev/null; then
          wait -n "$pid" 2>/dev/null || ret=$?
          found=true
        else
          bg_new_pids+=("$pid")
        fi
      done
      if $found; then
        BG_PIDS=("${bg_new_pids[@]}")
        ${BG_FAIL:-true} || return 0
        return $ret
      fi
      sleep "${BG_POLLRATE:-0.05}"
    done
  else
    wait -n "${BG_PIDS}" || true
    for pid in "${BG_PIDS[@]}"; do ! kill -0 "$pid" 2>/dev/null || bg_new_pids+=("$pid"); done
    BG_PIDS=("${bg_new_pids[@]}")
    return 0
  fi
}

bg_block() {
  [[ -n $BG_PIDS && ${BG_MAXPARALLEL:-4} -gt 0 ]] || return 0
  while [[ ${#BG_PIDS[@]} -ge ${BG_MAXPARALLEL:-4} ]]; do
    bg_waitany || return $?
  done
  return 0
}

bg_killall() {
  [[ -n $BG_PIDS ]] || return 0
  kill -"${1:-TERM}" "${BG_PIDS[@]}" 2>/dev/null || true
  return 0
}

bg_waitall() {
  [[ -n $BG_PIDS ]] || return 0
  while [[ ${#BG_PIDS[@]} -gt 0 ]]; do bg_waitany || return $?; done
  return 0
}
