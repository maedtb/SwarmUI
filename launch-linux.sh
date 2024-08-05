#!/usr/bin/env bash

# Ensure correct local path.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

# Add dotnet non-admin-install to path
export PATH="$SCRIPT_DIR/.dotnet:~/.dotnet:$PATH"

export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

if [ ! -d .git ]; then
    printf "\n\nWARNING: YOU DID NOT CLONE FROM GIT. THIS WILL BREAK SOME SYSTEMS. PLEASE INSTALL PER THE README.\n\n" >&2
fi

# Server settings option
if [ -d .git ] && [ -f ./src/bin/always_pull ]; then
    echo "Pulling latest changes..."
    git pull
fi

if [ -f ./src/bin/must_rebuild ]; then
    echo "Rebuilding..."
elif [ -d .git ]; then
    cur_head=`git rev-parse HEAD`
    built_head=`test -e ./src/bin/last_build && cat ./src/bin/last_build || echo 0`
    if [ "$cur_head" != "$built_head" ]; then
        printf "\n\nWARNING: You did a git pull without building. Will now build for you...\n\n" >&2
        touch ./src/bin/must_rebuild
    fi
fi

# Build the program if it isn't already built or we are rebuilding
if [ ! -f ./src/bin/live_release/SwarmUI.dll ] || [ -e ./src/bin/must_rebuild ]; then
    [ -e ./src/bin/must_rebuild ] && rm -fr ./src/bin/must_rebuild
    [ -e ./src/bin/live_release_backup ] && rm -rf ./src/bin/live_release_backup
    [ -e ./src/bin/live_release ] && mv ./src/bin/live_release ./src/bin/live_release_backup
    dotnet build ./src/SwarmUI.csproj --configuration Release -o ./src/bin/live_release
    if [ -d .git ]; then
        cur_head=`git rev-parse HEAD`
        echo $cur_head > ./src/bin/last_build
    fi
fi

# Default env configuration, gets overwritten by the C# code's settings handler
export ASPNETCORE_ENVIRONMENT="Production"
export ASPNETCORE_URLS="http://*:7801"
# Actual runner.
dotnet ./src/bin/live_release/SwarmUI.dll $@

# Exit code 42 means restart, anything else = don't.
if [ $? == 42 ]; then
    . ./launch-linux.sh $@
fi
