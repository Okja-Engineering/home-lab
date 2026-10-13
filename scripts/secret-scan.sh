#!/bin/sh
# The repository's secret scan. The pre-commit hook and the CI workflow both
# run this script, so both apply the same rules and the same checks.
#
#   scripts/secret-scan.sh staged    the staged changes (pre-commit hook)
#   scripts/secret-scan.sh history   every commit reachable from HEAD (CI)
#
# gitleaks must be on PATH. pre-commit builds it from the commit pinned in
# .pre-commit-config.yaml; the workflow installs the release pinned in
# .github/workflows/secret-scan.yml. Both are v8.30.1.
#
# Exit status: 0 when nothing was found and the scan read what it was asked
# to; 1 when something was found or the scan cannot be trusted; 2 when the
# script was called wrongly.
set -eu

usage() {
  echo "usage: $0 staged|history" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage
mode=$1

# What gitleaks reads. In both modes it has git print a diff and scans the
# lines that diff adds. It therefore never scans a file that git treats as
# binary, such as an etcd snapshot or an archive (git prints no text for it,
# and gitleaks does not open archives), a line that was removed, or a commit
# message.
case "$mode" in
  staged)
    # `git diff --staged`: the lines the commit being made adds.
    set -- --pre-commit --staged
    # No commit exists yet, so gitleaks reports 0 commits.
    commits='[0-9]+'
    ;;
  history)
    # gitleaks runs `git log -p -U0` with these options, split on single
    # spaces. That prints, for every commit reachable from HEAD, the lines it
    # adds; for a merge commit, the lines it adds to its first parent, which
    # include anything the merge itself introduced. Not printed, and so not
    # scanned: commits that HEAD is not built on (other branches, tags, commits
    # removed by a force-push), and a path whose type changes in that commit,
    # such as a symlink replaced by a file (the "t" in --diff-filter).
    #
    # gitleaks' own default is "--full-history --all --diff-filter=tuxdb".
    # HEAD replaces --all, which would also read every other branch the
    # checkout fetched and fail this scan for a finding on an unrelated one.
    # --diff-merges=first-parent is added because git prints no diff at all
    # for a merge commit without it.
    set -- "--log-opts=--full-history --diff-merges=first-parent --diff-filter=tuxdb NO-SUCH-REF"
    commits='[1-9][0-9]*'
    ;;
  *)
    usage
    ;;
esac

# Two passes over the same changes, one per rule set:
#   .gitleaks-talos.toml  the Talos rules, which have no allowlist and so
#                         apply to every path
#   .gitleaks.toml        gitleaks' default rules, with gitleaks' default
#                         allowlist of paths
configs='.gitleaks-talos.toml .gitleaks.toml'

cd "$(git rev-parse --show-toplevel)"

if ! command -v gitleaks >/dev/null; then
  echo "secret-scan: gitleaks is not on PATH" >&2
  exit 2
fi

log=$(mktemp)
trap 'rm -f "$log"' EXIT

failed=0
for config in $configs; do
  echo "secret-scan: ${mode}, rules from ${config}" >&2

  # --redact keeps a detected secret out of the output, which is public in CI.
  # Do not add --log-level debug: it prints decoded values and defeats
  # --redact. --no-color keeps the log lines plain for the checks below.
  status=0
  gitleaks git --config "$config" "$@" --redact --verbose --no-banner --no-color 2>"$log" || status=$?
  cat "$log" >&2

  if [ "$status" -ne 0 ]; then
    echo "secret-scan: FAILED: gitleaks exited with status ${status} (1 means it found something)" >&2
    failed=1
  fi

  # The exit status alone does not show that the changes were read. gitleaks
  # v8.30.1 starts git itself, and when that git command fails, or only prints
  # a warning, gitleaks logs the message at error level, stops reading at
  # whatever point it has reached, reports "no leaks found" and exits 0
  # (https://github.com/gitleaks/gitleaks/issues/2129). So the scan passes
  # only if gitleaks logged no error and reported the scan it finished.
  if grep -E -q '^[^ ]+ ERR( |$)' "$log"; then
    echo "secret-scan: FAILED: gitleaks logged an error (ERR above), so it did not read all the changes" >&2
    failed=1
  fi
  if ! grep -E -q "^[^ ]+ INF ${commits} commits scanned\.\$" "$log"; then
    echo "secret-scan: FAILED: gitleaks did not report the commits it scanned (history must have at least one)" >&2
    failed=1
  fi
done

exit "$failed"
