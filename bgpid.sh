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
  bg_block "${BG_MAXPARALLEL:-4}" || return $?
}

bg_run() {
  bg_init || return $?
  bg_block "${BG_MAXPARALLEL:-4}" || return $?
  "$@" & BG_PIDS+=($!)
}

bg_killall() {
  [[ ${#BG_PIDS[@]} -eq 0 ]] || kill -"${1:-TERM}" "${BG_PIDS[@]}" 2>/dev/null || true
  while [[ ${#BG_PIDS[@]} -gt 0 ]]; do
    bg_waitany || true
  done
  return 0
}

# shellcheck disable=2120
bg_block() {
  local lvl=${1:-0}
  [[ $lvl -ne -1 ]] || return 0
  local ret=0
  while [[ ${#BG_PIDS[@]} -ne 0 && ${#BG_PIDS[@]} -ge $lvl ]]; do
    bg_waitany || { ret=$?; break; }
  done
  if [[ $ret -gt 0 ]]; then
    if [[ -n $BG_SIGNAL ]]; then
      [[ ${#BG_PIDS[@]} -eq 0 ]] || kill -"$BG_SIGNAL" "${BG_PIDS[@]}" 2>/dev/null || true
    fi
    while [[ ${#BG_PIDS[@]} -gt 0 ]]; do
      bg_waitany || true
    done
  fi
  return $ret
}

bg_waitany() {
  [[ $BG_PIDS_OWNER = "$BASHPID" ]] || return 0
  local pid found=false ret=0 bg_new_pids=()
  while [[ ${#BG_PIDS[@]} -gt 0 ]]; do
    for pid in "${BG_PIDS[@]}"; do
      if ! $found && ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" 2>/dev/null || ret=$?
        found=true
      else
        bg_new_pids+=("$pid")
      fi
    done
    if $found; then
      BG_PIDS=("${bg_new_pids[@]}")
      return $ret
    else
      bg_new_pids=()
      sleep "${BG_POLLRATE:-0.05}"
    fi
  done
}
