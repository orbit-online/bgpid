# bgpid

Tooling for handling background processes in Bash.

## Installation

With [μpkg](https://github.com/orbit-online/upkg)

```
upkg install -g orbit-online/bgpid@<VERSION>
```

## Usage

### Global variables

#### $BG_PIDS

Array containing the background PIDs bgpid is aware of. You may manually add
PIDs to it (`BG_PIDS+=($!)`) if the API does not satisfy a use-case, this does
not interfere with the inner workings of bgpid.

#### $BG_MAXPARALLEL

The maximum number of processes to run in parallel.  
Set to 0 to disable the limit.

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

### Functions

#### bg_add(pid)

Add the given PID to `$BG_PIDS`, then run `bg_block` before returning.  
Fails when `bg_block` fails (but will still add the PID).

#### bg_run(...cmd)

Run `bg_block`, then start `...cmd` in the background and add its PID to
`$BG_PIDS`. Returns early and does not start `...cmd` when `bg_block` fails.

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

#### bg_waitall()

Wait for all processes in `$BG_PIDS` to exit.  
Returns early if any of the processes exit with a non-zero code and
`BG_FAIL=true`, otherwise always returns `0`.
