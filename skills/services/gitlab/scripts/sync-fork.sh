#!/bin/bash
# Sync Fork Script
# Automates: fetch upstream → fast-forward current branch → push to origin
#
# This is a STRICT fast-forward sync: if the branch cannot be fast-forwarded
# onto upstream, the script stops without creating a merge commit or pushing,
# leaving the decision (rebase, merge, etc.) to the user.

set -euo pipefail

BRANCH="${1:-main}"
UPSTREAM_REMOTE="${2:-upstream}"

# Save current branch up front so cleanup can return to it.
CURRENT_BRANCH=$(git branch --show-current)

cleanup() {
    # Return to the original branch if we switched away from it.
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
        local now
        now=$(git branch --show-current)
        if [ "$now" != "$CURRENT_BRANCH" ]; then
            echo "📍 Returning to $CURRENT_BRANCH..."
            git checkout "$CURRENT_BRANCH"
        fi
    fi
}
trap cleanup EXIT

echo "🔄 Syncing fork with upstream..."
echo "  Branch: $BRANCH"
echo "  Upstream remote: $UPSTREAM_REMOTE"
echo ""

# Check if upstream remote exists
if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    echo "❌ Upstream remote '$UPSTREAM_REMOTE' not found"
    echo ""
    echo "Add upstream remote first:"
    echo "  git remote add upstream <upstream-repo-url>"
    echo ""
    echo "Example:"
    echo "  git remote add upstream https://gitlab.com/group/project.git"
    exit 1
fi

UPSTREAM_URL=$(git remote get-url "$UPSTREAM_REMOTE")
echo "Upstream: $UPSTREAM_URL"
echo ""

# Checkout target branch
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    if [ -z "$CURRENT_BRANCH" ]; then
        echo "ℹ️  Detached HEAD detected; will not auto-return after switching."
    fi
    echo "📍 Switching to $BRANCH..."
    git checkout "$BRANCH"
fi

# Fetch upstream
echo "⬇️  Fetching from upstream..."
git fetch "$UPSTREAM_REMOTE"

# Fast-forward only — never create a merge commit.
echo "🔀 Fast-forwarding $BRANCH to upstream/$BRANCH..."
if git merge "$UPSTREAM_REMOTE/$BRANCH" --ff-only; then
    echo "✅ Fast-forward successful"
else
    echo "❌ Cannot fast-forward $BRANCH onto $UPSTREAM_REMOTE/$BRANCH"
    echo ""
    echo "Your branch has diverged from upstream (local commits or rewritten"
    echo "history). No merge commit was created and nothing was pushed."
    echo ""
    echo "Decide how to integrate the changes yourself, e.g.:"
    echo "  git rebase $UPSTREAM_REMOTE/$BRANCH    # replay your commits on top"
    echo "  git merge $UPSTREAM_REMOTE/$BRANCH     # explicit merge commit"
    echo ""
    echo "Then push when you are satisfied:"
    echo "  git push origin $BRANCH"
    exit 1
fi

# Push to origin (only reached on a clean fast-forward)
echo "⬆️  Pushing to origin/$BRANCH..."
git push origin "$BRANCH"

echo ""
echo "✨ Fork synced successfully!"
echo ""
echo "Summary:"
echo "  ✅ Fetched from $UPSTREAM_REMOTE"
echo "  ✅ Fast-forwarded local $BRANCH to upstream/$BRANCH"
echo "  ✅ Pushed to origin/$BRANCH"
