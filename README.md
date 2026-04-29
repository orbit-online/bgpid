# bgpid

Tooling for handling background processes in Bash.

## Contents

- [Installation](#installation)
- [Usage](#usage)
  - [Functions](#functions)
  - [Global variables](#global-variables)
  - [Examples](#examples)

## Installation

See [the latest release](https://github.com/orbit-online/bgpid/releases/latest) for instructions.

## Usage

### Functions

#### bg_run(...cmd)

Run `bg_block $(( BG_MAXPARALLEL - 1 ))` (or just `$BG_MAXPARALLEL` if
`$BG_MAXPARALLEL <= 0`), then start `...cmd` in the background and add its PID
to `$BG_PIDS`. `$!` is preserved (meaning its value is the PID of the process
that was started).  
Returns the return code of the `bg_block` call and does not start `...cmd` if
`bg_block` returns with a non-zero return code.

#### bg_block([MAX=0])

Wait until there are no more than `$MAX` running processes.  
Return `0` if all processes that completed while blocking returned `0`.  
otherwise, return the exit code of one of the failed processes.

Set `$BG_SIGNAL` to have bg_block call `bg_killall $BG_SIGNAL` before returning
with a non-zero exit code (this in turn means `bg_block` will only return once
all process have exited, not when the `$MAX` threshhold is reached).

#### bg_killall([SIGNAL=TERM])

Kill all running processes and wait for them to exit.  
Always returns `0`.

#### bg_add(pid)

Add the given PID to `$BG_PIDS`, then run `bg_block $BG_MAXPARALLEL`.

Useful when running subshells that you don't want to wrap in a function, e.g.:

```
(
  out=$(do thing)
  process "$out"
) & bg_add $!
```

Note that `bg_block` must be run before `bg_add` in order to not launch more
processes than `$BG_MAXPARALLEL` allows. If you are fine with
`$BG_MAXPARALLEL + 1` you can omit it.

#### bg_waitany()

Wait for any process in `$BG_PIDS` to exit and return its exit code.  
Return `0` when no processes are running.

#### bg_init()

Initialize `$BG_PIDS` and `$BG_PIDS_OWNER`. This function is useful if you
intend to read or modify `$BG_PIDS`.

### Global variables

#### $BG_PIDS

Array containing the background PIDs bgpid is aware of. You may manually add
PIDs to it (`BG_PIDS+=($!)`) if e.g. the API does not satisfy a use-case, this
does not interfere with the inner workings of bgpid.  
However, to make sure you are not working with the array that was inherited from
a parent process run `bg_init()` first.

#### $BG_SIGNAL

The signal to send to all other processes when `bg_block` detects a failed
process while blocking.

Default: `<UNSET>`

#### $BG_MAXPARALLEL

The maximum number of processes to run in parallel.  
Set to a negative value to disable the limit.

Default: `4`

#### $BG_PIDS_OWNER

`$BG_PIDS` is a global variable (and therefore visible in subprocesses).
In order to maintain separation between parent and child processes,
this variable contains the owning process PID of `$BG_PIDS`.

### Examples

#### Run a set of tasks and wait for completion

```
for task in "${tasks[@]}; do
  bg_run run_task "$task"
done
bg_block
```

#### Run a set of watchers and exit when any of them fails

```
trap bg_killall SIGTERM SIGHUP SIGINT ERR
BG_MAXPARALLEL=-1 BG_SIGNAL=TERM
bg_run program --watch
bg_run other-program --wait
bg_run server --foreground
bg_block
```
