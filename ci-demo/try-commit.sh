#!/bin/bash
# DEMONSTRATION ONLY. Not part of story/18-secret-scanning. DO NOT MERGE.
#
# Stages one file, runs `git commit` with the pre-commit hook installed, says
# whether a commit was created, and compares that with what is required.
#
#   ci-demo/try-commit.sh token|clean committed|blocked "<state>"
#
# "token" stages a visibly fake token: repeated letters in the Talos token
# shape. It is assembled here from two words, so that no file on this branch
# holds the shape the rules look for. "clean" stages a benign text file.
set -u
what=$1
required=$2
state=$3

mkdir -p ci-demo
case "$what" in
  token)
    file=ci-demo/hook-fixture.yaml
    {
      echo '# FAKE FIXTURE. NOT A SECRET. Repeated letters only.'
      printf 'anyName: %s.%s\n' aaaaaa bbbbbbbbbbbbbbbb
    } > "$file"
    ;;
  clean)
    file=ci-demo/benign.txt
    echo "a benign change, staged under: ${state}" > "$file"
    ;;
  *)
    echo "usage: $0 token|clean committed|blocked <state>" >&2
    exit 2
    ;;
esac
git add "$file"

echo "=== state: ${state} | staged: ${what}"
echo "colour settings: $(git config --get-regexp '^color\.' | tr '\n' ' ')" \
  "GIT_PAGER_IN_USE=${GIT_PAGER_IN_USE:-} TERM=${TERM:-}"
echo "first line of the staged diff as git writes it to a pipe: $(git diff -U0 --no-ext-diff --staged . | head -1 | cat -v)"

before=$(git rev-parse HEAD)
git commit -m "demonstration: ${what} under ${state}" > "${RUNNER_TEMP}/commit.log" 2>&1
status=$?
after=$(git rev-parse HEAD)
sed 's/^/    | /' "${RUNNER_TEMP}/commit.log"

if [ "$before" = "$after" ]; then
  got=blocked
  git reset -q -- "$file"
  rm -f "$file"
else
  got=committed
  git reset -q --hard "$before"
fi

if [ "$got" = "$required" ]; then
  echo "RESULT: staged ${what} under [${state}]: commit ${got} (git commit exit ${status}). As required."
else
  echo "RESULT: staged ${what} under [${state}]: commit ${got} (git commit exit ${status}). REQUIRED: ${required}."
  exit 1
fi
