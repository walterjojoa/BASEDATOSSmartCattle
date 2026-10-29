#!/usr/bin/env bash
# Every migration file must be referenced by install.sql, in order.
#
# This is the drift that nothing else detects. CI applies the migrations
# directory with a loop, so a migration missing its \i line passes every
# other step, and only a database installed by the documented path comes out
# incomplete. Checking artefacts does not help either: the artefact list
# would have to be updated by the same person who forgot the \i line.
set -euo pipefail

cd "$(dirname "$0")/.."

listed=$(grep -oE 'database/migrations/[0-9]{4}_[a-z0-9_]+\.sql' database/install.sql \
         | sed 's#database/migrations/##')
present=$(find database/migrations -name '*.sql' -printf '%f\n' | sort)

missing=$(comm -23 <(echo "$present") <(echo "$listed" | sort) || true)
unknown=$(comm -13 <(echo "$present") <(echo "$listed" | sort) || true)

status=0
if [ -n "$missing" ]; then
    echo "install.sql no lista estas migraciones:" >&2
    echo "$missing" | sed 's/^/  - /' >&2
    status=1
fi
if [ -n "$unknown" ]; then
    echo "install.sql lista archivos que no existen:" >&2
    echo "$unknown" | sed 's/^/  - /' >&2
    status=1
fi

# And in order: psql runs them top to bottom, so a 0010 listed after a 0020
# applies out of sequence.
if [ "$listed" != "$(echo "$listed" | sort)" ]; then
    echo "install.sql lista las migraciones fuera de orden" >&2
    status=1
fi

[ "$status" -eq 0 ] && echo "install.sql lista las $(echo "$present" | wc -l | tr -d ' ') migraciones, en orden"
exit "$status"
