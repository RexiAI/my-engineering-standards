#!/usr/bin/env bash
# token-stats.sh — where the tokens actually went, read from opencode's own
# session store. This adds no telemetry: the harness already records cost and
# five token buckets per session, so the correct move is to query it rather
# than invent a second schema.
#
# Usage:
#   scripts/token-stats.sh [-d <directory>] [-m <YYYY-MM>] [-n <top>] [-a] [-p <db>]
#     -d  session directory to report on (default: this repo's root, so the
#         same command works in a child repo consuming this submodule)
#     -m  restrict to one month, e.g. 2026-10 (default: all months)
#     -n  how many top sessions to list (default: 10)
#     -a  every directory, not just -d
#     -p  database path (default: $OPENCODE_DB or
#         ~/.local/share/opencode/opencode.db)
#
# Read-only: the database is opened with mode=ro and never written.
#
# Exit: 0 = report printed (an empty selection prints zeros)
#       1 = database missing/unreadable, or python3 absent
#       2 = usage error
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
DIR="$ROOT"
MONTH=""
TOP=10
ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    -d) DIR="${2:-}"; [ -n "$DIR" ] || { echo "token-stats: -d requires a path" >&2; exit 2; }; shift 2 ;;
    -m) MONTH="${2:-}"; [ -n "$MONTH" ] || { echo "token-stats: -m requires YYYY-MM" >&2; exit 2; }; shift 2 ;;
    -n) TOP="${2:-}"; case "$TOP" in ''|*[!0-9]*) echo "token-stats: -n requires a positive integer" >&2; exit 2 ;; esac; shift 2 ;;
    -p) DB="${2:-}"; [ -n "$DB" ] || { echo "token-stats: -p requires a path" >&2; exit 2; }; shift 2 ;;
    -a) ALL=1; shift ;;
    -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "token-stats: unknown argument '$1' (try -h)" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "token-stats: python3 not found" >&2; exit 1; }
[ -r "$DB" ] || { echo "token-stats: database not readable: $DB" >&2; exit 1; }

DIR="$DIR" MONTH="$MONTH" TOP="$TOP" ALL="$ALL" DB="$DB" python3 <<'PY'
import json, os, sqlite3, sys
from datetime import datetime, timezone

db = os.environ["DB"]
month = os.environ.get("MONTH", "")
top = int(os.environ.get("TOP", "10"))
all_dirs = os.environ.get("ALL") == "1"
sel_dir = os.environ.get("DIR", "")

try:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
except sqlite3.Error as e:
    sys.exit(f"token-stats: cannot open {db}: {e}")
con.row_factory = sqlite3.Row

COLS = ("tokens_input", "tokens_output", "tokens_reasoning",
        "tokens_cache_read", "tokens_cache_write")
q = "select agent, model, cost, directory, time_created, title, " + ", ".join(COLS) + " from session"
rows = []
for r in con.execute(q):
    if not all_dirs and (r["directory"] or "") != sel_dir:
        continue
    if month:
        ts = r["time_created"] or 0
        if datetime.fromtimestamp(ts / 1000, timezone.utc).strftime("%Y-%m") != month:
            continue
    rows.append(r)

def parts(r):
    return json.loads(r["model"]) if r["model"] else {}

def label(r):
    m = parts(r)
    return f"{m.get('providerID', '?')}/{m.get('id', '?')}"

def tot(r):
    return sum(r[c] or 0 for c in COLS)

scope = "all directories" if all_dirs else sel_dir
print(f"# token-stats — {scope}" + (f" — {month}" if month else " — all months"))
print(f"# sessions: {len(rows)}   source: {db}")
if not rows:
    print("no sessions matched")
    raise SystemExit(0)

grand = sum(tot(r) for r in rows)
cost = sum(r["cost"] or 0 for r in rows)
print(f"\n## totals   {grand/1e6:.1f}M tokens   ${cost:.2f} recorded cost")
print(f"{'bucket':<16}{'tokens':>16}{'share':>9}")
for c in COLS:
    v = sum(r[c] or 0 for r in rows)
    print(f"{c.replace('tokens_',''):<16}{v:>16,}{(v/grand*100 if grand else 0):>8.2f}%")
print(f"\ncost driver: cache_read is context re-sent every turn, so it scales with")
print(f"turns x session length — not with the size of any one file.")

def agg(key):
    out = {}
    for r in rows:
        k = key(r)
        a = out.setdefault(k, [0, 0.0, 0, 0])
        a[0] += 1
        a[1] += r["cost"] or 0
        a[2] += tot(r)
        a[3] += r["tokens_output"] or 0
    return sorted(out.items(), key=lambda kv: -kv[1][2])

print(f"\n## by agent + model")
print(f"{'agent':<22}{'model':<44}{'n':>4}{'tokens M':>10}{'share':>8}{'cost$':>9}")
for (a, m), v in agg(lambda r: (r["agent"] or "-", label(r))):
    print(f"{a:<22}{m:<44}{v[0]:>4}{v[2]/1e6:>10.1f}{v[2]/grand*100:>7.1f}%{v[1]:>9.2f}")

print(f"\n## by provider")
for p, v in agg(lambda r: label(r).split("/")[0]):
    print(f"{p:<28}{v[0]:>4} sess{v[2]/1e6:>10.1f}M{v[2]/grand*100:>7.1f}%{v[1]:>10.2f}")

print(f"\n## by month")
by_month = sorted(agg(lambda r: datetime.fromtimestamp(
    (r["time_created"] or 0) / 1000, timezone.utc).strftime("%Y-%m")), key=lambda kv: kv[0])
for mo, v in by_month:
    print(f"{mo:<10}{v[0]:>4} sess{v[2]/1e6:>10.1f}M{v[2]/grand*100:>7.1f}%{v[1]:>10.2f}")

print(f"\n## top {top} sessions by tokens")
for r in sorted(rows, key=tot, reverse=True)[:top]:
    print(f"{tot(r)/1e6:>8.1f}M {(r['agent'] or '-'):<20}{parts(r).get('id','?'):<22}"
          f"${r['cost'] or 0:>7.2f}  {(r['title'] or '')[:44]}")
PY
