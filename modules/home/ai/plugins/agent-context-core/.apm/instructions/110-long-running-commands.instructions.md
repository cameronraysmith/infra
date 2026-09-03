---
description: Long-running, streaming, or later-input-needing commands run as managed background processes captured with tee into logs/, never a bare blocking call.
---

## Long-running commands

A command that will run for a long time, stream output, or need input later belongs in a managed background process, not a blocking foreground call that ties up the turn waiting on it.

The capture itself is absolute and the numeric thresholds are advisory.
Any command expected to run longer than roughly thirty seconds or produce more than roughly ten lines is run as:

    <command> 2>&1 | tee logs/<lower-kebab-identifier>-$(date +%Y%m%d-%H%M%S).log

A `tail` or filter may follow the `tee`, never replace it.
A pipeline reports the exit status of its last stage, so piping straight to `tail` has already reported a real lint failure as success in this fleet; output exists once, so a discarded portion is unrecoverable and every later question costs a re-run; a state-mutating command cannot be re-run at all, so its evidence is simply gone; and a human cannot `tail -f` a pipeline, so skipping capture silently removes their ability to watch work they delegated.

Where the log files live and how the directory is verified is owned by the `preferences-style-and-conventions` skill's "File organization" section.
