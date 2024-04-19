#!/usr/bin/env bats
# shellcheck disable=1065,2030,2031,2034

setup_file() {
  bats_require_minimum_version 1.5.0
}

setup() {
  export BG_MAXPARALLEL=4
  export BG_FAIL=true
}

ret() {
  return "${1:-0}"
}
export -f ret

sleep_ret() {
  sleep "${1:-.3}"
  return "${2:-0}"
}
export -f sleep_ret

@test 'bg_waitall returns 0 when all processes succeed' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  bg_run true
  bg_waitall
  "
}

@test 'bg_waitall does not return before all exited' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  bg_run sleep_ret
  bg_run sleep_ret
  bg_waitall
  [ \"\$(jobs -p)\" = '' ]"
}

@test 'BG_FAIL=false bg_waitall returns 1 when a process fails but not before all exited' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  BG_FAIL=false
  bg_run sleep_ret
  bg_run ret 1
  ! bg_waitall
  [ \"\$(jobs -p)\" = '' ]"
}

@test 'BG_FAIL=true bg_waitall exits early when any process fails' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  bg_run sleep_ret
  bg_run ret 1
  ! bg_waitall
  [ \"\$(jobs -p)\" != '' ]
  "
}

@test 'bg_run fails when bg_block fails' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  bg_run ret 1
  bg_run ret
  bg_run ret
  bg_run ret
  # bg_waitany unshifts the first process and fails
  ! bg_run ret
  "
}

@test 'bg_killall sends signal to all processes' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  bg_run sleep_ret 10
  bg_run sleep_ret 10
  bg_run sleep_ret 10
  bg_killall
  sleep .2
  [ \"\$(jobs -p)\" = '' ]
  "
}

@test 'bg_block blocks then fails if a process fails' {
  ! bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  BG_MAXPARALLEL=1
  bg_run sleep_ret .1 1
  bg_block
  " || false
}

@test 'subshell invocations do not inherit BG_PIDS' {
  bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  bg_run ret 1
  (bg_waitall)
  "
}

@test 'bg_init fails when BASHPID is not set' {
  ! bash -ec "close_non_std_fds; source $BATS_TEST_DIRNAME/bgpid.sh; set -e
  unset BASHPID
  bg_run ret 1
  " || false
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
export -f get_open_fds

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
export -f close_non_std_fds

function close_fds() { # <fds...>
  for fd in "$@"; do
    eval "exec $fd>&-"
  done
}
export -f close_fds
