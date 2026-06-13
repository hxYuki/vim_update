# Vim Update

A Neovim plugin that detects local configuration drift from a Git remote on startup and guides the user through synchronization.

## Language

**Update**:
`git pull --rebase` executed against the tracked remote branch.

**Sync Check**:
The comparison between local HEAD and the tracked remote ref, performed by `git fetch` on startup.

**Behind**:
Local HEAD is behind the tracked remote — remote has commits that local does not.
_Trigger_: Fetch at startup detects this. Leads to dialog or notification.

**Ahead**:
Local HEAD is ahead of the tracked remote — local has unpushed commits.
_Trigger_: Fetch at startup detects this. Leads to notification or auto-push, depending on configuration.

**Forked**:
Both Behind and Ahead simultaneously — local and remote have diverged.
_Trigger_: Fetch at startup detects this. Requires manual resolution.

**Interactive Dialog**:
A floating window displayed after idle startup (before user enters Insert mode) offering actions: Update, View Changes, Ignore.

**Notification**:
A `vim.notify` call that passively informs the user of an available action, used when the editor is already active (e.g. Insert mode or after the interaction window has passed).

**Auto Push**:
Automatic execution of `git push` when Ahead, triggered after a configurable delay from the earliest unpushed commit's author date.

**View Changes**:
Display of the remote commit log (`git log HEAD..origin/main --oneline`) via an integrated Git UI (lazygit, neogit, fugitive) or a scratch buffer as fallback.
