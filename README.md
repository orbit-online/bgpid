# bgpid

Tooling for handling background processes in Bash.

## Contents

- [Installation](#installation)
- [Usage](#usage)
  - [Functions](#functions)
  - [Global variables](#global-variables)

## Installation

With [μpkg](https://github.com/orbit-online/upkg)

```
upkg install -g orbit-online/bgpid@<VERSION>
```

## Usage

### Functions

#### bg_add(pid)

Add the given PID to `$BG_PIDS`, then run `bg_block` before returning.  
Fails when `bg_block` fails (but will still add the PID).

Useful when running subshells that you don't want to wrap in a function, e.g.:

```
bg_block
(
  out=$(do thing)
  process "$out"
) & bg_add $!
bg_waitall
```

Note that `bg_block` must be run before `bg_add` in order to not launch more
processes than `$BG_MAXPARALLEL` allows. If you are fine with
`$BG_MAXPARALLEL + 1` you can omit it.

#### bg_run(...cmd)

Run `bg_block`, then start `...cmd` in the background and add its PID to
`$BG_PIDS`.  
Returns early and does not start `...cmd` when `bg_block` fails.

#### bg_waitany()

Wait for exactly one process in `$BG_PIDS` to exit and returns its exit code.  
Returns `0` when no processes are running.

#### bg_block()

Block as long as the current number of PIDs in `$BG_PIDS` is equal to or exceeds
`$BG_MAXPARALLEL`.  
Returns the exit code of the process whose completion resolved the blocking (if
any, otherwise `0`)

#### bg_killall([SIGNAL=TERM])

Send `SIGNAL` to all processes in `$BG_PIDS`.

Default signal: `TERM`

#### bg_waitall([CONT=true])

Wait for all processes in `$BG_PIDS` to exit.  
When `CONT=true` wait for all processes to complete and return `0` if all
processes returned `0` otherwise return the exit code of the last failed
process.  
When `CONT=false` return early if any of the processes exit with a non-zero
code.

#### bg_init()

Initializes `$BG_PIDS` and `$BG_PIDS_OWNER`. This function is useful if you
intend to read or modify `$BG_PIDS`.

### Global variables

#### $BG_PIDS

Array containing the background PIDs bgpid is aware of. You may manually add
PIDs to it (`BG_PIDS+=($!)`) if the API does not satisfy a use-case, this does
not interfere with the inner workings of bgpid.  
However, to make sure you are not working with the array that was inherited from
a parent process run `bg_init()` first.

#### $BG_MAXPARALLEL

The maximum number of processes to run in parallel.  
Set to `0` to disable the limit.

Default: `4`

#### $BG_POLLRATE

The rate in seconds at which `bg_waitany()` should check whether one of the
background processes has exited.

Default: `0.05`

_Note: This is needed because calling `wait -n id...` returns the status of all
stopped processes, meaning failing exit codes may be hidden. If you know of a
way to block the process until a PID changes status and then get the exit code
of only that process, please open an issue, I'm all ears._

#### $BG_PIDS_OWNER

`$BG_PIDS` is a global variable (and therefore visible in subprocesses).
In order to maintain separation between parent and child processes,
this variable contains the owning process PID of `$BG_PIDS`.
