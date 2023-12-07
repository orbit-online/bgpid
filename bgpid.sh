#!/usr/bin/env bash
# shellcheck disable=2128

bg_init() {
  [[ -n $BASHPID ]] || { printf "bgpid.sh: \$BASHPID is not set" >&2; return 1; }
  if [[ -z $BG_PIDS || $BG_PIDS_OWNER != "$BASHPID" ]]; then
    BG_PIDS_OWNER=$BASHPID
    BG_PIDS=()
  fi
}

bg_add() {
  bg_init || return $?
  BG_PIDS+=("$1")
  bg_block || return $?
}

bg_run() {
  bg_init || return $?
  bg_block || return $?
  "$@" & BG_PIDS+=($!)
}

bg_waitany() {
  [[ $BG_PIDS_OWNER = "$BASHPID" && -n $BG_PIDS ]] || return 0
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
  [[ $BG_PIDS_OWNER = "$BASHPID" && ${BG_MAXPARALLEL:-4} -gt 0 && -n $BG_PIDS ]] || return 0
  while [[ ${#BG_PIDS[@]} -ge ${BG_MAXPARALLEL:-4} ]]; do
    bg_waitany || return $?
  done
  return 0
}

bg_killall() {
  [[ $BG_PIDS_OWNER = "$BASHPID" && -n $BG_PIDS ]] || return 0
  kill -"${1:-TERM}" "${BG_PIDS[@]}" 2>/dev/null || true
  return 0
}

bg_waitall() {
  [[ $BG_PIDS_OWNER = "$BASHPID" && -n $BG_PIDS ]] || return 0
  while [[ ${#BG_PIDS[@]} -gt 0 ]]; do bg_waitany || return $?; done
  return 0
}
