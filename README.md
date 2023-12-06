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

Note that `bg_block` must be run in order to not launch more processes than
`$BG_MAXPARALLEL` allows. If you are fine with `$BG_MAXPARALLEL + 1` you can
omit it.

#### bg_run(...cmd)

Run `bg_block`, then start `...cmd` in the background and add its PID to
`$BG_PIDS`.  
Returns early and does not start `...cmd` when `bg_block` fails.

#### bg_waitany()

When `BG_FAIL=true` wait for exactly one process in `$BG_PIDS` to exit.  
Returns the exit code of the process that exited.

When `BG_FAIL=true` wait for one or more processes in `$BG_PIDS` to exit.  
Always returns `0`.

#### bg_block()

Block as long as the current number of PIDs in `$BG_PIDS` is equal to or exceeds
`$BG_MAXPARALLEL`.  
Returns early if any of the processes exit with a non-zero code and
`BG_FAIL=true`, otherwise always returns `0`.

#### bg_killall([SIGNAL])

Send `SIGNAL` to all processes in `$BG_PIDS`.

Default signal: `TERM`

It is recommended to wait for the processes afterwards with `bg_waitall`.
Note that most processes will exit with `$? > 0` when terminated unexpectedly,
so if you want to continue the script after waiting, you may want to set
`BG_FAIL=false` for that call only:

```
bg_run do something
bg_killall
BG_FAIL=false bg_waitall
```

#### bg_waitall()

Wait for all processes in `$BG_PIDS` to exit.  
When `BG_FAIL=true` return early if any of the processes exit with a
non-zero code.  
When `BG_FAIL=false` ignore exit codes from all processes and always return `0`.

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

#### $BG_FAIL

Whether to propagate failures of background processes.

Default: `true`

#### $BG_POLLRATE

Not used when `BG_FAIL=false`.  
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
