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

bg_block() {
  [[ ${BG_MAXPARALLEL:-4} -gt 0 ]] || return 0
  local ret=0
  bg_drain $((${BG_MAXPARALLEL:-4} - 1)) || ret=$?
  if [[ $ret -gt 0 ]]; then
    if [[ -n $BG_SIGNAL ]]; then
      [[ ${#BG_PIDS[@]} -eq 0 ]] || kill -"$BG_SIGNAL" "${BG_PIDS[@]}" 2>/dev/null || true
    fi
    bg_drain 0 || ret=$?
  fi
  return $ret
}

bg_drain() {
  [[ $BG_PIDS_OWNER = "$BASHPID" ]] || return 0
  local lvl=${1:-0} ret=0
  while [[ ${#BG_PIDS[@]} -gt $lvl ]]; do
    bg_waitany || ret=$?
  done
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
