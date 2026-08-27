#!/bin/sh
#
# fleet — launcher detection
#
# Prints how THIS installation of Claude Code should be invoked to dispatch a
# background agent. The coordinator skill runs this instead of hardcoding a
# command, because three things vary per machine and none of them are guessable:
#
#   1. the binary name and location (claude, a wrapper, a version manager shim);
#   2. the config directory (CLAUDE_CONFIG_DIR — profiles/multiple accounts);
#   3. whether the user drives Claude Code through a shell alias.
#
# Aliases matter but cannot be used directly: a non-interactive shell — which is
# what a tool call runs in — does not expand them. So we report the alias for the
# human's benefit and emit its EXPANDED form as the command to actually run.
#
# Output is KEY=VALUE lines plus `#` comments. Values are already shell-quoted
# where quoting could matter, so LAUNCHER_CMD can be used verbatim.
#
# Exit codes: 0 = a usable launcher was found; 1 = no Claude Code binary found.

set -u

# ---------------------------------------------------------------- quoting help

# Single-quote a value for safe reuse in a shell command.
shquote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# --------------------------------------------------------------- find the binary

CLAUDE_BIN=""
if command -v claude >/dev/null 2>&1; then
    CLAUDE_BIN=$(command -v claude)
else
    # Common install locations, in case PATH is thinner inside a tool call than
    # it is in the user's interactive shell.
    for candidate in \
        "$HOME/.local/bin/claude" \
        "$HOME/.claude/local/claude" \
        "$HOME/bin/claude" \
        /opt/homebrew/bin/claude \
        /usr/local/bin/claude \
        /usr/bin/claude
    do
        if [ -x "$candidate" ]; then
            CLAUDE_BIN="$candidate"
            break
        fi
    done
fi

if [ -z "$CLAUDE_BIN" ]; then
    echo "# error: no Claude Code binary found on PATH or in the usual locations."
    echo "# Install it, or set FLEET_LAUNCHER to the command that starts a session."
    echo "CLAUDE_BIN="
    echo "LAUNCHER_CMD="
    exit 1
fi

# ------------------------------------------------------------- the config profile

# An inherited CLAUDE_CONFIG_DIR means the current session runs against a
# non-default profile. Dispatched agents MUST inherit it, or they come up against
# a different account and cannot see this workspace's skills, agents or memory.
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-}"

# ------------------------------------------------------------------- find an alias

# Look for an alias that wraps the binary. When several match, prefer one whose
# definition mentions the config dir we are actually running under.
LAUNCHER_ALIAS=""
ALIAS_DEFINITION=""

for rc in \
    "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" \
    "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" \
    "$HOME/.config/fish/config.fish"
do
    [ -r "$rc" ] || continue

    # Matches: alias name='...claude...'  /  alias name="...claude..."
    matches=$(grep -hE "^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_.-]+=.*claude" "$rc" 2>/dev/null || true)
    [ -n "$matches" ] || continue

    # Iterate without a subshell so assignments survive.
    OLD_IFS=$IFS
    IFS='
'
    for line in $matches; do
        name=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*alias[[:space:]]+([A-Za-z0-9_.-]+)=.*/\1/')
        body=$(printf '%s' "$line" | sed -E "s/^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_.-]+=//; s/^[\"']//; s/[\"'][[:space:]]*(#.*)?$//")

        # Skip aliases that merely mention claude in a comment or a longer word.
        case "$body" in
            *claude*) ;;
            *) continue ;;
        esac

        if [ -z "$LAUNCHER_ALIAS" ]; then
            LAUNCHER_ALIAS="$name"
            ALIAS_DEFINITION="$body"
        fi

        # A stronger match wins: this alias pins the profile we are running under.
        if [ -n "$CONFIG_DIR" ]; then
            expanded=$(printf '%s' "$body" | sed "s|~|$HOME|g")
            case "$expanded" in
                *"$CONFIG_DIR"*)
                    LAUNCHER_ALIAS="$name"
                    ALIAS_DEFINITION="$body"
                    ;;
            esac
        fi
    done
    IFS=$OLD_IFS

    [ -n "$LAUNCHER_ALIAS" ] && break
done

# ------------------------------------------------------- probe supported flags

HELP=$("$CLAUDE_BIN" --help 2>/dev/null || true)

supports() {
    case "$HELP" in
        *"$1"*) echo "yes" ;;
        *) echo "no" ;;
    esac
}

SUPPORTS_BG=$(supports "--bg")
SUPPORTS_EFFORT=$(supports "--effort")
SUPPORTS_NAME=$(supports "--name")
SUPPORTS_MODEL=$(supports "--model")

# ------------------------------------------------------------ build the command

# An explicit override always wins — for wrappers we cannot infer (devcontainers,
# remote shells, corporate launchers).
if [ -n "${FLEET_LAUNCHER:-}" ]; then
    LAUNCHER_CMD="$FLEET_LAUNCHER"
    LAUNCHER_SOURCE="FLEET_LAUNCHER override"
elif [ -n "$CONFIG_DIR" ]; then
    LAUNCHER_CMD="CLAUDE_CONFIG_DIR=$(shquote "$CONFIG_DIR") $(shquote "$CLAUDE_BIN")"
    LAUNCHER_SOURCE="binary + inherited CLAUDE_CONFIG_DIR"
else
    LAUNCHER_CMD="$(shquote "$CLAUDE_BIN")"
    LAUNCHER_SOURCE="binary on PATH (default profile)"
fi

# ------------------------------------------------------------------ emit results

echo "# fleet launcher detection"
echo "CLAUDE_BIN=$(shquote "$CLAUDE_BIN")"
echo "CLAUDE_CONFIG_DIR=$(shquote "$CONFIG_DIR")"
echo "LAUNCHER_ALIAS=$LAUNCHER_ALIAS"
echo "LAUNCHER_ALIAS_DEFINITION=$(shquote "$ALIAS_DEFINITION")"
echo "LAUNCHER_CMD=$LAUNCHER_CMD"
echo "LAUNCHER_SOURCE=$LAUNCHER_SOURCE"
echo "SUPPORTS_BG=$SUPPORTS_BG"
echo "SUPPORTS_NAME=$SUPPORTS_NAME"
echo "SUPPORTS_MODEL=$SUPPORTS_MODEL"
echo "SUPPORTS_EFFORT=$SUPPORTS_EFFORT"

if [ -n "$LAUNCHER_ALIAS" ]; then
    echo "# The user drives Claude Code through the '$LAUNCHER_ALIAS' alias."
    echo "# Say '$LAUNCHER_ALIAS' when you talk to them; run LAUNCHER_CMD when you dispatch."
    echo "# Aliases do not expand in non-interactive shells, which is what tool calls use."
fi

if [ -n "$CONFIG_DIR" ]; then
    echo "# This session runs on a non-default profile. Dispatched agents inherit it via"
    echo "# LAUNCHER_CMD; drop that prefix and they wake up on the wrong account, unable to"
    echo "# see this workspace's skills, agents and memory."
fi

if [ "$SUPPORTS_BG" = "no" ]; then
    echo "# warning: this build advertises no --bg flag. Background dispatch may be"
    echo "# unavailable; check 'claude --help' and fall back to whatever this build offers."
fi

if [ "$SUPPORTS_EFFORT" = "no" ]; then
    echo "# note: no --effort flag in this build. Omit it; do not raise the model to"
    echo "# compensate — an under-specified front is not fixed by a bigger model."
fi

exit 0
