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
  local max=${BG_MAXPARALLEL:-4}
  (( max <= 0 )) || : $(( max-- ))
  bg_block "$max" || return $?
  "$@" & BG_PIDS+=($!)
}

bg_killall() {
  [[ $BG_PIDS_OWNER = "$BASHPID" ]] || return 0
  (( ${#BG_PIDS[@]} == 0 )) || kill -"${1:-TERM}" "${BG_PIDS[@]}" 2>/dev/null || true
  while (( ${#BG_PIDS[@]} > 0 )); do
    bg_waitany || true
  done
  return 0
}

bg_block() {
  bg_init || return $?
  local max=${1:-0}
  (( max >= 0 )) || return 0
  local ret=0
  while (( ${#BG_PIDS[@]} > max )); do
    bg_waitany || ret=$?
    if [[ $ret -gt 0 && -n $BG_SIGNAL ]]; then
      bg_killall "$BG_SIGNAL"
      break
    fi
  done
  return $ret
}

bg_waitany() {
  [[ $BG_PIDS_OWNER = "$BASHPID" ]] || return 0
  local pid found=false ret=0 bg_new_pids=()
  local original_opts=$-; set +x
  while (( ${#BG_PIDS[@]} > 0 )); do
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
      [[ $original_opts != *x* ]] || set -x
      return $ret
    else
      bg_new_pids=()
      sleep "${BG_POLLRATE:-0.05}"
    fi
  done
  [[ $original_opts != *x* ]] || set -x
}
