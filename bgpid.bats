#!/usr/bin/env bats
# shellcheck disable=1065,2030,2031,2034

load "$BATS_TEST_DIRNAME/bgpid.sh"

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  bats_require_minimum_version 1.5.0
  BG_MAXPARALLEL=4
  BG_FAIL=true
}

ret() {
  close_non_std_fds
  return "${1:-0}"
}

sleep_ret() {
  close_non_std_fds
  sleep "${1:-.3}"
  return "${2:-0}"
}

@test 'bg_waitall does not return before all exited' {
  bg_run sleep_ret
  bg_run sleep_ret
  bg_waitall
  [ "$(jobs -p)" = '' ]
}

@test 'bg_waitall fails when any process fails' {
  bg_run ret
  bg_run ret
  bg_run ret
  bg_run ret 1
  ! bg_waitall || false
}

@test 'bg_run fails when bg_block fails' {
  bg_run ret 1
  bg_run ret
  bg_run ret
  bg_run ret
  # bg_waitany unshifts the first process and fails
  ! bg_run ret || false
}

@test 'bg_killall sends signal to all processes' {
  bg_run sleep_ret 10
  bg_run sleep_ret 10
  bg_run sleep_ret 10
  bg_killall
  sleep .2
  [ "$(jobs -p)" = '' ]
}

@test 'bg_block blocks then fails if a process fails' {
  BG_MAXPARALLEL=1
  bg_run sleep_ret .1 1
  ! bg_block || false
}

@test 'bg_waitall does not fail when BG_FAIL=false' {
  BG_FAIL=false
  bg_run ret 1
  bg_waitall
}

@test 'subshell invocations do not inherit BG_PIDS' {
  bg_run ret 1
  (bg_waitall)
}

@test 'bg_init fails when BASHPID is not set' {
  unset BASHPID
  ! bg_run ret 1 || false
}


# See
# https://bats-core.readthedocs.io/en/stable/gotchas.html#background-tasks-prevent-the-test-run-from-terminating-when-finished
# https://github.com/bats-core/bats-core/issues/205#issuecomment-973572596
# Source: https://github.com/bats-core/bats-core/blob/e9fd17a70721e447313691f239d297cecea6dfb7/test/fixtures/bats/issue-205.bats
get_open_fds() {
  open_fds=() # reset output array in case it was already set
  if [[ ${BASH_VERSINFO[0]} == 3 ]]; then
    local BASHPID
    BASHPID=$(bash -c 'echo $PPID')
  fi
  local tmpfile
  tmpfile=$(mktemp "$BATS_SUITE_TMPDIR/fds-XXXXXX")
  # Avoid opening a new fd to read fds: Don't use <(), glob expansion.
  # Instead, redirect stdout to file which does not create an extra FD.
  if [[ -d /proc/$BASHPID/fd ]]; then # Linux
    ls -1 "/proc/$BASHPID/fd" >"$tmpfile"
    IFS=$'\n' read -d '' -ra open_fds <"$tmpfile" || true
  elif command -v lsof >/dev/null; then # MacOS
    local -a fds
    lsof -F f -p "$BASHPID" >"$tmpfile"
    IFS=$'\n' read -d '' -ra fds <"$tmpfile" || true
    for fd in "${fds[@]}"; do
      case $fd in
      f[0-9]*)                # filter non fd entries (mainly pid?)
        open_fds+=("${fd#f}") # cut off f prefix
        ;;
      esac
    done
  elif command -v procstat >/dev/null; then # BSDs
    local -a columns header
    procstat fds "$BASHPID" >"$tmpfile"
    {
      read -r -a header
      local fd_column_index=-1
      for ((i = 0; i < ${#header[@]}; ++i)); do
        if [[ ${header[$i]} == *FD* ]]; then
          fd_column_index=$i
          break
        fi
      done
      if [[ $fd_column_index -eq -1 ]]; then
        printf "Could not find FD column in procstat" >&2
        exit 1
      fi
      while read -r -a columns; do
        local fd=${columns[$fd_column_index]}
        if [[ $fd == [0-9]* ]]; then # only take up numeric entries
          open_fds+=("$fd")
        fi
      done
    } <"$tmpfile"
  else
    # TODO: MSYS (Windows)
    printf "Neither FD discovery mechanism available\n" >&2
    exit 1
  fi
}

close_non_std_fds() {
  local open_fds non_std_fds=()
  get_open_fds
  for fd in "${open_fds[@]}"; do
    if [[ $fd -gt 2 ]]; then
      non_std_fds+=("$fd")
    fi
  done
  close_fds "${non_std_fds[@]}"
}

function close_fds() { # <fds...>
  for fd in "$@"; do
    eval "exec $fd>&-"
  done
}
