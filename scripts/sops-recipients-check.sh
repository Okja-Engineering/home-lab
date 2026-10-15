#!/bin/sh
# Check the SOPS rule and the encrypted Talos secrets bundle, without decrypting anything.
#
#   scripts/sops-recipients-check.sh [--require-bundle] [EXPECTED_AGE_RECIPIENT]
#
# Reads what git will publish (the index copies of .sops.yaml and of
# platform/talos/clusters/home-prod/secrets.sops.yaml), never the working tree. Passes only when:
#   - each of the two holds only printable ASCII and line feeds, so it splits into lines here just
#     as it does in sops's YAML parser, which also breaks lines at CR, NEL, LS and PS, and refuses NUL;
#   - .sops.yaml's non-comment lines are exactly the one creation rule, with one age X25519 recipient
#     (and that recipient is EXPECTED, when given);
#   - no other secrets.sops.yaml exists anywhere in the checkout, staged or not;
#   - the bundle, when staged, has exactly the shape sops writes for one age recipient (keys and
#     ENC[...] values, then a sops: section whose every line is allowed), its recipient: line is that
#     recipient, and its enc holds exactly one X25519 stanza;
#   - a bundle in the working tree that is not staged fails; with --require-bundle, it must be staged.
# What this cannot show is whose key the one stanza opens; the owner shows that by decrypting once
# with his key (issue 19). Any git failure fails the check.
# Needs sh, git, grep, sed, awk, tr, cmp and age-inspect (shipped with age 1.3.2).
# Exit 0 when all hold; 1 when anything is wrong or unexpected; 2 on wrong usage or a missing tool.
# It exits 0 in one place only: its last line. A shell reads a script one command at a time, so by
# then it has read every line above, and a syntax error anywhere has already stopped it. There is
# no EXIT trap, because under macOS /bin/sh (bash 3.2) a shell that stops on a syntax error or an
# unset variable while an EXIT trap is set exits 0. fail removes the work directory itself; a stop
# exits non-zero, and may leave that directory behind, holding only copies of what is staged.
set -eu

fail() {
  echo "sops-recipients-check: FAILED: $*" >&2
  rm -rf "$work"
  exit 1
}
usage() {
  echo "usage: $0 [--require-bundle] [age-recipient]" >&2
  exit 2
}
# True when every byte of the file is printable ASCII or a line feed.
printable() {
  LC_ALL=C tr -cd '\n -~' < "$1" | cmp -s - "$1"
}

require=0
if test "${1:-}" = --require-bundle; then
  require=1
  shift
fi
test "$#" -le 1 || usage
command -v age-inspect > /dev/null || { echo "sops-recipients-check: age-inspect is not on PATH" >&2; exit 2; }
work="$(mktemp -d)"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "not inside a git repository"
cd "$top"
b=platform/talos/clusters/home-prod/secrets.sops.yaml
x25519='age1[02-9ac-hj-np-z]{58}'

git cat-file blob :.sops.yaml > "$work/rule" 2>/dev/null || fail ".sops.yaml is not committed or staged"
printable "$work/rule" || fail ".sops.yaml holds a byte other than printable ASCII and line feeds"
body="$(grep -v -E '^[[:space:]]*(#|$)' "$work/rule" || true)"
recipient="$(printf '%s\n' "$body" | sed -n -E "3s/^    age: ($x25519)\$/\\1/p")"
want="$(printf '%s\n' 'creation_rules:' '  - path_regex: platform/talos/clusters/.*/secrets\.sops\.yaml$' "    age: $recipient")"
if test -z "$recipient" || test "$body" != "$want"; then
  fail ".sops.yaml is not exactly one creation rule with one age X25519 recipient"
fi
if test "$#" -eq 1; then
  test -n "$1" || fail "the expected recipient given is empty"
  test "$1" = "$recipient" || fail ".sops.yaml's recipient is not the expected one"
fi
echo "ok: .sops.yaml is the one rule, with one age X25519 recipient${1:+, the expected one}"

listed="$(git ls-files --cached --others --exclude-standard -- ':(glob)**/secrets.sops.yaml')" || fail "git ls-files failed"
others="$(printf '%s\n' "$listed" | grep -v -x -F -e "$b" -e '' || true)"
test -z "$others" || fail "another secrets.sops.yaml is in the checkout: $(printf '%s' "$others" | tr '\n' ' ')"
staged="$(git ls-files --cached -- "$b")" || fail "git ls-files failed"
if test -z "$staged"; then
  if test -e "$b" || test -L "$b"; then
    fail "$b is in the working tree but not staged; git add it first"
  fi
  test "$require" = 0 || fail "$b is not staged, and --require-bundle was given"
  verdict="no secrets.sops.yaml yet"
else
  git cat-file blob ":$b" > "$work/bundle" || fail "git could not read the staged $b"
  printable "$work/bundle" || fail "the staged $b holds a byte other than printable ASCII and line feeds"
  awk -v rec="$recipient" -v out="$work/enc" '
    BEGIN { s = "data"; encs = 0 }
    s == "data" && /^sops:$/ { s = "age"; next }
    s == "data" && /^(    )*[a-z0-9]+:$/ { next }
    s == "data" && /^(    )*[a-z0-9]+: ENC\[AES256_GCM,data:[A-Za-z0-9+\/=]+,iv:[A-Za-z0-9+\/=]+,tag:[A-Za-z0-9+\/=]+,type:(str|int|float|bool)\]$/ { encs++; next }
    s == "age" && $0 == "    age:" { s = "entry"; next }
    s == "entry" && $0 == "        - enc: |" { s = "begin"; next }
    s == "begin" && $0 == "            -----BEGIN AGE ENCRYPTED FILE-----" { print substr($0, 13) > out; s = "armor"; next }
    s == "armor" && /^            [A-Za-z0-9+\/=]+$/ { print substr($0, 13) > out; lines++; next }
    s == "armor" && lines > 0 && $0 == "            -----END AGE ENCRYPTED FILE-----" { print substr($0, 13) > out; s = "rec"; next }
    s == "rec" && $0 == "          recipient: " rec { s = "lm"; next }
    s == "lm" && /^    lastmodified: "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z"$/ { s = "mac"; next }
    s == "mac" && /^    mac: ENC\[AES256_GCM,data:[A-Za-z0-9+\/=]+,iv:[A-Za-z0-9+\/=]+,tag:[A-Za-z0-9+\/=]+,type:str\]$/ { s = "suffix"; next }
    s == "suffix" && $0 == "    unencrypted_suffix: _unencrypted" { s = "version"; next }
    s == "version" && /^    version: [0-9]+\.[0-9]+\.[0-9]+$/ { s = "end"; next }
    { bad = 1; exit }
    END { exit (bad || s != "end" || encs == 0) ? 1 : 0 }
  ' "$work/bundle" || fail "the staged $b is not exactly a sops file with one age recipient, the one in .sops.yaml"
  age-inspect --json "$work/enc" | tr -d ' \n\t' | grep -q '"stanza_types":\["X25519"\]' ||
    fail "the staged $b: its age entry does not hold exactly one X25519 stanza"
  verdict="the staged $b has one age recipient, the one in .sops.yaml, and one X25519 stanza"
fi
rm -rf "$work"
echo "ok: $verdict"
