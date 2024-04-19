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

bg_killall() {
  [[ $BG_PIDS_OWNER = "$BASHPID" && ${#BG_PIDS[@]} -gt 0 ]] || return 0
  kill -"${1:-TERM}" "${BG_PIDS[@]}" 2>/dev/null || true
  return 0
}

bg_block() {
  [[ ${BG_MAXPARALLEL:-4} -eq 0 ]] || bg_drain $((${BG_MAXPARALLEL:-4} - 1))
}

bg_drain() {
  local lvl=${1:-0} cont=${2:-true}
  [[ $BG_PIDS_OWNER = "$BASHPID" && ${#BG_PIDS[@]} -gt $lvl ]] || return 0
  local cur_ret ret=0
  while [[ ${#BG_PIDS[@]} -gt $lvl ]]; do
    cur_ret=0
    bg_waitany || cur_ret=$?
    [[ $cur_ret != 0 ]] || continue
    if $cont; then
      ret=$cur_ret
    else
      return $cur_ret
    fi
  done
  return $ret
}

bg_waitany() {
  [[ $BG_PIDS_OWNER = "$BASHPID" && ${#BG_PIDS[@]} -gt 0 ]] || return 0
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
