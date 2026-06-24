# Everyday jj workflows

Practical recipes to teach once the core model (jj-vs-git.md) clicks. Have the
learner run each in a scratch repo and narrate `jj log` / `jj op log` after.

## Make some changes
```
jj new -m "Implement feature"   # start a fresh change off @
# edit files — they're already in @, no `add`
jj status                       # see what changed
jj diff                         # review the working-copy commit
jj describe -m "Better message" # update the change description any time
```

## Stack work (no branches)
```
jj new -m "Part 1"
# …edit…
jj new -m "Part 2"   # Part 2's parent is Part 1; a stack forms automatically
jj log               # see the stack
```
Each change keeps a stable change-id even as you reshuffle the stack.

## Amend / squash
```
# To fold the working copy into its parent change:
jj squash
# To move only some files/hunks down:
jj squash --interactive
# To edit an older change directly:
jj edit <change-id>   # @ moves there; descendants auto-rebase when you're done
```

## Split a change in two
```
jj split          # interactively choose what stays vs goes to a new child change
```

## Rebase / reorder
```
jj rebase -d <dest-change>            # move a change (and descendants) onto dest
jj rebase -s <source> -d <dest>       # move a subtree
```
Descendants are rebased automatically; conflicts are recorded in the commits, so
you can continue and resolve them when convenient (`jj resolve`).

## Bookmarks and pushing
```
jj bookmark set my-feature -r @       # point a bookmark at a change
jj git push --bookmark my-feature     # push it (creates/updates the remote branch)
jj git fetch                          # pull remote updates
```
Introduce bookmarks only when it's time to push/share — before that, work
branchlessly by change-id.

## Undo and time-travel (the safety net)
```
jj op log                 # every operation, newest first
jj undo                   # reverse the most recent operation
jj op restore <op-id>     # jump the whole repo back to a past state
```
Encourage deliberate mistakes followed by `jj undo` so the learner trusts it.

## Inspecting
```
jj log                    # change graph (change-ids, descriptions, bookmarks)
jj log -r 'all()'         # everything, using the revset language
jj show <change-id>       # full details + diff of a change
```
