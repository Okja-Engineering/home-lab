#!/usr/bin/env bash
# Check the Talos machine configs: that the documented block generates them, and that they hold the
# values platform/talos/clusters/home-prod/metadata.env records. The talos-config job in
# .github/workflows/validate.yml runs it on every pull request. It runs on a workstation too.
#
#   scripts/talos-config-check.sh
#
# It never reads or writes the cluster's real secrets. It copies the repository's tracked files, as
# they are in the working tree, to a temporary directory, and commits them there with a throwaway
# secrets bundle that sops encrypts to a throwaway age key. Then, in that copy:
#   1. It finds the three marked paste blocks (talos-generate-configs, cilium-install and
#      cilium-ready). Each must appear once, between its markers, and its command must not appear in
#      fenced code anywhere else: a copy would drift. No block may hold a "#", which zsh, with its
#      default options, runs as a command.
#   2. It runs the talos-generate-configs block as it is written: from docs/ with bash, over a 0644
#      decoy at secrets/secrets.yaml, which the bundle's plaintext must replace with mode 0600, and
#      each node's CA must be the bundle's; then from the top of the copy with zsh (with bash where
#      zsh is missing), which must give the same machine configs and a new talosconfig.
#   3. It checks each node's config against metadata.env. It also runs the same checks on the
#      generator's output without the patches, which must fail exactly the checks for the values the
#      patches set.
#   4. It checks that each of the block's refusals stops it with its own reason and changes nothing,
#      and that the block stops at a failing command.
# It prints "ok <check>" or "FAIL <check>: expected ..., got ...", with values that are not secret.
# It never prints a generated config, the bundle or a key. Everything it writes is in one temporary
# directory, removed at the end, with one exception on macOS: there mktemp -d ignores TMPDIR, so each
# refusal case that stops after the block's own mktemp -d leaves that tmp.* directory in the per-user
# temporary folder (getconf DARWIN_USER_TEMP_DIR). Each holds committed files and the throwaway
# bundle, encrypted to a key that no longer exists.
#
# Needs bash 5 or later, git, talosctl at metadata.env's TALOS_VERSION, sops, age-keygen, yq (v4),
# python3, tar, awk, cmp and sha256sum. Exit status: 0 when every check passed, 1 when one failed,
# 2 when bash is older than 5 or a tool is missing.
test "${BASH_VERSINFO[0]:-0}" -ge 5 || { echo "talos-config-check: needs bash 5 or later" >&2; exit 2; }
set -euo pipefail

me=talos-config-check
d=platform/talos/clusters/home-prod
nodes=(cp-01 cp-02 cp-03)

# The checks the generator's output without the patches must fail, and no others: the values the
# patches exist to set.
selftest_red=(
  "no KubeFlannelCNIConfig" "KubeProxyConfig.enabled" "no control-plane taint"
  "one Layer2VIPConfig" "VIP address"
  "one LinkAliasConfig" "alias selector" "VIP link is the alias"
  "one LinkConfig" "LinkConfig name is the alias" "static address" "default route"
  "hostname" "hostname auto"
  "name servers" "time servers" "NTS"
  "installer image" "install disk selector"
)

# A line of fenced code holding one of these is a copy of that block's command. They are passed to
# awk through the environment: awk -v would process the backslashes of a regex.
signatures=(
  'talosctl gen config .*[$][{]?CLUSTER_ENDPOINT'
  'helm install cilium '
  'expected 3 nodes, found'
)

mode=check # "check" prints ok and FAIL lines; "selftest" prints a SELFTEST-RED line per failed check
red=()     # the names of the checks that failed in the current mode
failures=0

finished=no # set by every deliberate exit; the EXIT trap reports any other

ok() { echo "ok $*"; }
fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}
# die MESSAGE: a FAIL line, then stop; what follows depends on this step.
die() {
  fail "$@"
  finished=yes
  exit 1
}
# The EXIT trap: remove the work directory. set -e stops the script at a command that fails
# unexpectedly; say so, so that such a stop is never silent.
on_exit() {
  local rc=$?
  rm -rf "$work"
  if test "$rc" != 0 && test "$finished" != yes; then echo "$me: stopped early (status $rc)" >&2; fi
}

# eq NAME EXPECTED GOT [NODE]: the check passes only when EXPECTED is neither empty nor null and GOT
# equals it.
eq() {
  local name="$1" want="$2" got="$3" where="${4:+ ($4)}"
  if test -n "$want" && test "$want" != null && test "$want" = "$got"; then
    if test "$mode" = check; then echo "ok $name$where"; fi
    return 0
  fi
  red+=("$name")
  if test "$mode" = selftest; then
    echo "SELFTEST-RED $name$where: expected ${want:-(empty)}, got ${got:-(empty)}"
  else
    fail "$name$where: expected ${want:-(empty)}, got ${got:-(empty)}"
  fi
}

# q EXPRESSION FILE...: yq over every document of the files, given as separate arguments (cat
# would merge their documents). Prints nothing when yq fails, which fails the check.
q() {
  local out
  out="$(yq ea "$1" "${@:2}" < /dev/null 2> /dev/null)" || out=""
  printf '%s' "$out"
}

# The subnets must be IPv4 networks clear of the nodes' subnet.
subnets_report() {
  python3 -I - "$@" << 'EOF'
import ipaddress
import sys

node = ipaddress.ip_network(sys.argv[1], strict=False)
subnets = sys.argv[2:]
problems = [] if subnets else ["no subnets"]
for s in subnets:
    try:
        n = ipaddress.ip_network(s)
    except ValueError:
        problems.append(s + " is not a network")
        continue
    if n.version != 4:
        problems.append(s + " is not IPv4")
    elif n.overlaps(node):
        problems.append(s + " overlaps the node network " + str(node))
print("; ".join(problems) or "IPv4 and clear of the node network")
EOF
}

# check_node CONFIG NODE VALUES: one node's generated config against metadata.env (and, for
# KubePrism's port, against the Cilium values).
check_node() {
  local f="$1" n="$2" values="$3" ip_var ip alias kind name pods services
  ip_var="CP_0${n#cp-0}_IP"
  ip="${!ip_var}"

  eq "one v1alpha1 document" 1 "$(q '[select(.version == "v1alpha1")] | length' "$f")" "$n"
  eq "one KubeClusterConfig" 1 "$(q '[select(.kind == "KubeClusterConfig")] | length' "$f")" "$n"
  eq "one KubeNodeConfig" 1 "$(q '[select(.kind == "KubeNodeConfig")] | length' "$f")" "$n"
  eq "one EPHEMERAL VolumeConfig" 1 \
    "$(q '[select(.kind == "VolumeConfig" and .name == "EPHEMERAL")] | length' "$f")" "$n"

  eq "no KubeFlannelCNIConfig" 0 "$(q '[select(.kind == "KubeFlannelCNIConfig")] | length' "$f")" "$n"
  eq "KubeProxyConfig.enabled" false "$(q '[select(.kind == "KubeProxyConfig")] | .[0].enabled' "$f")" "$n"
  eq "no control-plane taint" 0 \
    "$(q '[select(.kind == "KubeNodeConfig") | .taints // {} | keys | .[] |
      select(. == "node-role.kubernetes.io/control-plane")] | length' "$f")" "$n"

  eq "endpoint" "$CLUSTER_ENDPOINT" "$(q '[select(.kind == "KubeClusterConfig")] | .[0].endpoint' "$f")" "$n"
  # The block names the cluster with a literal, so this ties it to metadata.env.
  eq "cluster name" "$CLUSTER_NAME" "$(q '[select(.kind == "KubeClusterConfig")] | .[0].clusterName' "$f")" "$n"
  eq "one Layer2VIPConfig" 1 "$(q '[select(.kind == "Layer2VIPConfig")] | length' "$f")" "$n"
  eq "VIP address" "$CLUSTER_VIP" "$(q '[select(.kind == "Layer2VIPConfig")] | .[0].name' "$f")" "$n"

  alias="$(q '[select(.kind == "LinkAliasConfig")] | .[0].name' "$f")"
  eq "one LinkAliasConfig" 1 "$(q '[select(.kind == "LinkAliasConfig")] | length' "$f")" "$n"
  eq "alias selector" "link.bus_path == \"$NETWORK_INTERFACE_BUS_PATH\"" \
    "$(q '[select(.kind == "LinkAliasConfig")] | .[0].selector.match' "$f")" "$n"
  eq "VIP link is the alias" "$alias" "$(q '[select(.kind == "Layer2VIPConfig")] | .[0].link' "$f")" "$n"
  eq "one LinkConfig" 1 "$(q '[select(.kind == "LinkConfig")] | length' "$f")" "$n"
  eq "LinkConfig name is the alias" "$alias" "$(q '[select(.kind == "LinkConfig")] | .[0].name' "$f")" "$n"
  eq "static address" "$ip/$NODE_PREFIX_LENGTH" \
    "$(q '[select(.kind == "LinkConfig") | .addresses // [] | .[] | .address] | join(" ")' "$f")" "$n"
  eq "default route" "$DEFAULT_GATEWAY/default" \
    "$(q '[select(.kind == "LinkConfig") | .routes // [] | .[] |
      (.gateway // "") + "/" + (.destination // "default")] | join(" ")' "$f")" "$n"

  eq "hostname" "$n" "$(q '[select(.kind == "HostnameConfig")] | .[0].hostname' "$f")" "$n"
  eq "hostname auto" off "$(q '[select(.kind == "HostnameConfig")] | .[0].auto' "$f")" "$n"

  eq "name servers" "$DNS_SERVERS" \
    "$(q '[select(.kind == "ResolverConfig") | .nameservers // [] | .[] | .address] | join(" ")' "$f")" "$n"
  eq "time servers" "$NTP_SERVERS" \
    "$(q '[select(.kind == "TimeSyncConfig") | .ntp.servers // [] | .[]] | join(" ")' "$f")" "$n"
  eq "NTS" "$NTP_USE_NTS" "$(q '[select(.kind == "TimeSyncConfig")] | .[0].ntp.useNTS' "$f")" "$n"

  pods="$(q '[select(.kind == "KubeNetworkConfig") | .podSubnets // [] | .[]] | join(" ")' "$f")"
  services="$(q '[select(.kind == "KubeNetworkConfig") | .serviceSubnets // [] | .[]] | join(" ")' "$f")"
  eq "pod subnets" "$POD_SUBNETS" "$pods" "$n"
  eq "service subnets" "$SERVICE_SUBNETS" "$services" "$n"
  local -a subnets
  read -r -a subnets <<< "$pods $services"
  eq "subnets IPv4 and clear of the node network" "IPv4 and clear of the node network" \
    "$(subnets_report "$ip/$NODE_PREFIX_LENGTH" "${subnets[@]}")" "$n"

  eq "v1alpha1 has no old fields" 0 \
    "$(q '[select(.version == "v1alpha1") | .machine // {} | keys | .[] |
      select(. == "network" or . == "time" or . == "install")] | length' "$f")" "$n"
  eq "no ETCD VolumeConfig" 0 "$(q '[select(.kind == "VolumeConfig" and .name == "ETCD")] | length' "$f")" "$n"
  eq "nothing disables host IPv6" 0 \
    "$(q '[(.. | select(tag == "!!map") | keys | .[]), (.. | select(tag == "!!str"))] |
      map(select(tag == "!!str" and test("disable_ipv6|ipv6[.]disable"))) | length' "$f")" "$n"

  eq "installer image" "$TALOS_INSTALLER_IMAGE" \
    "$(q '[select(.kind == "UnattendedInstallConfig")] | .[0].installer.image' "$f")" "$n"
  eq "install disk selector" "disk.transport == \"$INSTALL_DISK_TRANSPORT\"" \
    "$(q '[select(.kind == "UnattendedInstallConfig")] | .[0].provisioning.diskSelector.match' "$f")" "$n"

  for kind in KubeletConfig:kubelet KubeAPIServerConfig:apiserver \
    KubeControllerManagerConfig:controller-manager KubeSchedulerConfig:scheduler; do
    name="${kind#*:}"
    kind="${kind%%:*}"
    eq "$name image" "v$KUBERNETES_VERSION" \
      "$(q "[select(.kind == \"$kind\")] | .[0].image | sub(\".*:\", \"\")" "$f")" "$n"
  done

  eq "KubePrism port is k8sServicePort" "$(q '.k8sServicePort' "$values")" \
    "$(q '[select(.kind == "KubePrismConfig")] | .[0].port' "$f")" "$n"
}

# check_sources CLUSTER_DIR: the generated subnets equal Talos's defaults, so only the patches show
# where they are set. Every node gets all-nodes.yaml, and each node's kubelet takes its cluster DNS
# address from the Service subnet, so they must be set there and nowhere else.
check_sources() {
  local dir="$1" p
  local -a others=()
  eq "subnets set in all-nodes.yaml" "pods $POD_SUBNETS, services $SERVICE_SUBNETS" \
    "$(q '[select(.kind == "KubeNetworkConfig")] |
      "pods " + ([.[] | .podSubnets // [] | .[]] | join(" ")) +
      ", services " + ([.[] | .serviceSubnets // [] | .[]] | join(" "))' "$dir/patches/all-nodes.yaml")"
  for p in "$dir"/patches/*.yaml "$dir"/nodes/*.yaml; do
    test "$p" = "$dir/patches/all-nodes.yaml" || others+=("$p")
  done
  eq "no other patch sets the subnets" 0 "$(q '[select(.kind == "KubeNetworkConfig")] | length' "${others[@]}")"
}

# The single-copy rule. Fenced code is CommonMark's: a run of 3 or more ` or ~ (behind any number of
# > blockquote markers and any indentation), closed by a run of the same character at least as long;
# a ` run whose info string holds a ` is not a fence. Indented code blocks are not checked. A marker
# is a whole line at column 0; a marker-shaped line anywhere else fails. Writes each block's code to
# $D12_OUT/<name>.sh, prints ok or FAIL per block, and exits 1 when anything failed.
# shellcheck disable=SC2016
d12_awk='
function bad(msg) { print "FAIL single copy: " msg; failed = 1 }
function closefile() {
  if (region) bad(file ":" regionline ": the " names[region] " begin marker has no end marker")
  region = 0; infence = 0
}
BEGIN {
  names[1] = "talos-generate-configs"; names[2] = "cilium-install"; names[3] = "cilium-ready"
  for (i = 1; i <= 3; i++) { sig[i] = ENVIRON["D12_SIG_" i]; idx[names[i]] = i }
  out = ENVIRON["D12_OUT"]
}
FNR == 1 { closefile(); file = FILENAME }
{
  line = $0
  if (!infence) {
    t = line
    sub(/^[ \t>]+/, "", t)
    sub(/[ \t]+$/, "", t)
    if (t ~ /^<!-- [a-z0-9-]+:(begin|end) -->$/) {
      nm = t
      sub(/^<!-- /, "", nm)
      sub(/:(begin|end) -->$/, "", nm)
      if (nm in idx) {
        i = idx[nm]
        kind = (t ~ /:begin -->$/) ? "begin" : "end"
        if (line != t) {
          bad(file ":" FNR ": the " nm " " kind " marker must start at column 0, alone on its line")
          next
        }
        if (kind == "begin") {
          if (region) { bad(file ":" FNR ": the " nm " markers begin inside the " names[region] " markers"); next }
          region = i; regionline = FNR; fences = 0; isbash = 0; begins[i]++
          where[i] = where[i] (where[i] == "" ? "" : ", ") file ":" FNR
        } else {
          if (region != i) { bad(file ":" FNR ": the " nm " end marker has no begin marker before it"); next }
          if (fences != 1 || !isbash) bad(file ":" regionline ": the " nm " markers must hold exactly one bash fence")
          pairs[i]++; region = 0
        }
        next
      }
    }
  }
  body = line
  while (match(body, /^[ \t]*>[ ]?/)) body = substr(body, RLENGTH + 1)
  match(body, /^[ \t]*/)
  rest = substr(body, RLENGTH + 1)
  if (!infence) {
    if (match(rest, /^(```+|~~~+)/)) {
      ch = substr(rest, 1, 1); len = RLENGTH; info = substr(rest, len + 1)
      if (ch == "`" && index(info, "`")) next
      sub(/^[ \t]+/, "", info); sub(/[ \t]+$/, "", info)
      infence = 1; fch = ch; flen = len; inregion = 0
      if (region) {
        fences++
        if (fences == 1 && info == "bash") { isbash = 1; inregion = 1 }
      }
    }
    next
  }
  if (substr(rest, 1, 1) == fch && match(rest, /^(```+|~~~+)[ \t]*$/)) {
    m = rest; sub(/[ \t]+$/, "", m)
    if (length(m) >= flen) { infence = 0; inregion = 0; next }
  }
  for (i = 1; i <= 3; i++)
    if (line ~ sig[i] && !(inregion && region == i))
      bad(file ":" FNR ": fenced code outside the " names[i] " markers repeats that block (" sig[i] ")")
  if (inregion && begins[region] == 1) print line > (out "/" names[region] ".sh")
}
END {
  closefile()
  for (i = 1; i <= 3; i++) {
    if (begins[i] == 0) bad("no " names[i] " markers in any tracked Markdown file")
    else if (begins[i] > 1)
      bad("the " names[i] " markers are found " begins[i] " times (" where[i] "); keep one block and link to it")
    else if (pairs[i] == 1) print "ok single copy: " names[i] " (" where[i] ")"
  }
  exit failed
}
'

# Run the extracted block the way a person pastes it: its text on the shell's standard input.
# run_block DIR [NAME=VALUE...] -- SHELL [ARG...]; the output goes to $work/block.out.
# HOME is an empty directory in the work directory, not unset: zsh sets an unset HOME back to the
# user's home, where git and sops would read the user's own configuration and keys. HISTFILE is in
# the work directory too, so an interactive shell never writes the user's history file.
run_block() {
  local dir="$1"
  local -a envs=()
  shift
  while test "$1" != --; do
    envs+=("$1")
    shift
  done
  shift
  (cd "$dir" && env HOME="$work/home" HISTFILE="$work/home/history" TMPDIR="$work/blocktmp" \
    GIT_CEILING_DIRECTORIES="$work" "${envs[@]}" "$@" < "$block") > "$work/block.out" 2>&1
}

# The block's output, indented. zsh ends without a newline and writes carriage returns; drop them.
show_block_output() { tr -d '\r' < "$work/block.out" | awk '{ print "    | " $0 }'; }

# Git for the copies: no global config is read (HOME is unset), commits are never signed, and no
# hook runs.
sgit() { git -c user.name=scratch -c user.email=scratch@invalid -c commit.gpgsign=false "$@"; }

# What a refusal must leave as it was: generated/, secrets/ and the directory outside the copy that
# the link cases point at. One line per path: its type, and a link's target or a file's mode and
# content hash. A path that is not there is "missing", so a deleted generated/ shows as a change.
snapshot() {
  local p f
  for p in "$r/$d/generated" "$r/$d/secrets" "$work/target"; do
    if ! test -e "$p" && ! test -L "$p"; then
      printf 'missing %s\n' "$p"
      continue
    fi
    find "$p" | LC_ALL=C sort
  done | while IFS= read -r f; do
    if test "${f%% *}" = missing; then
      printf '%s\n' "$f"
    elif test -L "$f"; then
      printf 'link %s -> %s\n' "$f" "$(readlink "$f")"
    elif test -f "$f"; then
      # ls -l | cut reads the mode the same way on macOS and Linux; stat's options differ.
      # shellcheck disable=SC2012
      printf 'file %s %s %s\n' "$f" "$(ls -l "$f" | cut -c1-10)" "$(sha256sum < "$f" | cut -c1-64)"
    elif test -d "$f"; then
      printf 'directory %s\n' "$f"
    elif test -p "$f"; then
      printf 'fifo %s\n' "$f"
    else
      printf 'other %s\n' "$f"
    fi
  done
}

# A fresh clone of the copy, with a sentinel in generated/, a known plaintext at
# secrets/secrets.yaml, and a directory outside it for the link cases to point at.
fresh_case() {
  rm -rf "$r" "$work/target" "$work/outside" "$work/other"
  git clone -q "$work/repo" "$r"
  mkdir -p "$r/$d/generated" "$r/$d/secrets" "$work/target"
  echo sentinel > "$r/$d/generated/sentinel"
  printf 'known plaintext\n' > "$r/$d/secrets/secrets.yaml"
  chmod 0644 "$r/$d/secrets/secrets.yaml"
  echo outside > "$work/target/file"
}

# refusal NAME KEYWORD DIR [NAME=VALUE...]: the block, run from DIR, must exit 1 with a "Stopping:"
# line holding KEYWORD, and change nothing.
refusal() {
  local name="$1" keyword="$2" dir="$3" before after stop rc=0
  shift 3
  before="$(snapshot)"
  run_block "$dir" "$@" -- bash || rc=$?
  after="$(snapshot)"
  stop="$(grep -m 1 '^Stopping: ' "$work/block.out" || true)"
  if test "$rc" = 1 && grep -qF "$keyword" <<< "$stop" && test "$before" = "$after"; then
    ok "refusal, $name: rc 1, \"$keyword\", generated/ and secrets/ unchanged"
  else
    test "$before" = "$after" || stop="${stop:-no Stopping line}; generated/, secrets/ or the link target changed"
    fail "refusal, $name: expected rc 1 and \"$keyword\" with nothing changed, got rc $rc: ${stop:-no Stopping line}"
  fi
}

# Check the tools, read metadata.env and make the work directory. HOME is not set (see the end of
# this file), so git and sops read no configuration or keys of the user's.
prepare() {
  local tool
  for tool in git talosctl sops age-keygen yq python3 tar awk cmp sha256sum; do
    command -v "$tool" > /dev/null || { echo "$me: $tool is not on PATH" >&2; exit 2; }
  done
  top="$(git rev-parse --show-toplevel 2> /dev/null)" || { echo "$me: run this inside the repository" >&2; exit 1; }
  test -f "$top/$d/metadata.env" || { echo "$me: $d/metadata.env is missing" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$top/$d/metadata.env"
  work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/talos-config.XXXXXX")"
  trap on_exit EXIT
  mkdir "$work/home" "$work/blocktmp"
  export SOPS_AGE_KEY_FILE="$work/age.txt"

  local v
  v="$(talosctl version --client --short)" || v=""
  if ! grep -qxF "Talos $TALOS_VERSION" <<< "$v"; then
    echo "$me: talosctl is not $TALOS_VERSION, the version metadata.env pins" >&2
    finished=yes
    exit 2
  fi
}

# The copy, in $work/repo: tracked paths, with their working-tree content, committed with a
# throwaway bundle. Submodules and deleted files are skipped; untracked and ignored files (secrets/,
# generated/) are never copied. .sops.yaml's recipient becomes a throwaway age key. The plaintext is
# written outside the copy and encrypted inside it, where the bundle goes.
make_copy() {
  local entry path last=""
  git -C "$top" ls-files -z --stage > "$work/index"
  : > "$work/files"
  while IFS= read -r -d '' entry; do
    path="${entry#*$'\t'}"
    case "$entry" in 160000\ *) continue ;; esac
    test "$path" != "$last" || continue
    last="$path"
    if test -e "$top/$path" || test -L "$top/$path"; then printf '%s\0' "$path" >> "$work/files"; fi
  done < "$work/index"
  mkdir "$work/repo"
  tar -C "$top" --no-recursion --null -T "$work/files" -cf - | tar -C "$work/repo" -xf -
  sgit -C "$work/repo" init -q -b main

  c="$work/repo/$d"
  age-keygen -o "$work/age.txt" 2> /dev/null
  age-keygen -o "$work/wrong-age.txt" 2> /dev/null
  test -f "$work/repo/.sops.yaml" || die "setup: .sops.yaml is not tracked"
  (cd "$work/repo" && PUB="$(age-keygen -y "$work/age.txt")" yq -i '(.creation_rules[].age) = strenv(PUB)' .sops.yaml)
  talosctl gen secrets -o "$work/plain.yaml" > /dev/null
  rm -rf "$c/secrets" "$c/secrets.sops.yaml"
  mkdir "$c/secrets"
  cp "$work/plain.yaml" "$c/secrets/secrets.sops.yaml"
  (cd "$work/repo" && sops --encrypt --in-place "$d/secrets/secrets.sops.yaml")
  mv "$c/secrets/secrets.sops.yaml" "$c/secrets.sops.yaml"
  rm -rf "$c/secrets"
  sgit -C "$work/repo" add -A -f .
  sgit -C "$work/repo" commit -q --no-verify -m "the copy, with a throwaway bundle"
}

# 1. One copy of each marked block. The talos-generate-configs block is written to $block.
find_blocks() {
  local -a md
  mkdir "$work/blocks"
  git -C "$work/repo" ls-files -z -- '*.md' > "$work/md"
  mapfile -d '' -t md < "$work/md"
  (cd "$work/repo" && D12_OUT="$work/blocks" D12_SIG_1="${signatures[0]}" D12_SIG_2="${signatures[1]}" \
    D12_SIG_3="${signatures[2]}" awk "$d12_awk" "${md[@]}" < /dev/null) > "$work/d12.out" || true
  cat "$work/d12.out"
  failures=$((failures + $(grep -c '^FAIL' "$work/d12.out" || true)))
  # A paste block holds no "#": zsh, with interactivecomments off as it is by default, runs a
  # comment as a command. CI has no zsh, so this is checked here.
  local name hash
  for name in talos-generate-configs cilium-install cilium-ready; do
    test -f "$work/blocks/$name.sh" || continue
    hash="$(grep -n -m 1 '#' "$work/blocks/$name.sh" || true)"
    if test -z "$hash"; then
      ok "no # in the $name block"
    else
      fail "no # in the $name block: block line ${hash%%:*}: ${hash#*:}"
    fi
  done
  block="$work/blocks/talos-generate-configs.sh"
  if ! grep -q '^ok single copy: talos-generate-configs ' "$work/d12.out"; then
    die "the talos-generate-configs block could not be found, so it was not run"
  fi
}

# 2. Run 1, from docs/ with bash, over a 0644 decoy at secrets/secrets.yaml (a second throwaway).
# Then run 2, from the top, with zsh where it is installed.
run_twice() {
  local n x bundle_ca
  talosctl gen secrets -o "$work/decoy.yaml" > /dev/null
  mkdir "$c/secrets"
  cp "$work/decoy.yaml" "$c/secrets/secrets.yaml"
  chmod 0644 "$c/secrets/secrets.yaml"
  echo "Run 1: the talos-generate-configs block, with bash, from docs/"
  if ! run_block "$work/repo/docs" -- bash; then
    show_block_output
    die "run 1: the block did not finish"
  fi
  show_block_output
  if cmp -s "$work/plain.yaml" "$c/secrets/secrets.yaml"; then
    ok "run 1 replaced the decoy at secrets/secrets.yaml with the committed bundle's plaintext"
  else
    fail "run 1 left secrets/secrets.yaml different from the committed bundle's plaintext"
  fi
  # shellcheck disable=SC2012
  eq "secrets/secrets.yaml mode" "-rw-------" "$(ls -l "$c/secrets/secrets.yaml" | cut -c1-10)"
  bundle_ca="$(q '.certs.os.crt' "$work/plain.yaml")"
  test -n "$bundle_ca" && test "$bundle_ca" != null && bundle_ca="$(printf '%s' "$bundle_ca" | sha256sum | cut -c1-64)"
  for n in "${nodes[@]}"; do
    x="$(q '[select(.version == "v1alpha1")] | .[0].machine.ca.crt' "$c/generated/$n.yaml")"
    test -n "$x" && test "$x" != null && x="$(printf '%s' "$x" | sha256sum | cut -c1-64)"
    eq "machine CA is the bundle's (SHA-256)" "$bundle_ca" "$x" "$n"
  done
  mkdir "$work/run1"
  for x in controlplane "${nodes[@]}"; do cp "$c/generated/$x.yaml" "$work/run1/"; done
  cp "$c/generated/talosconfig" "$work/run1/"

  local -a shell=(bash) shell_env=()
  if command -v zsh > /dev/null; then
    # shellcheck disable=SC2016
    if test "$(env HOME="$work/home" HISTFILE="$work/home/history" zsh -f -c 'printf "%s %s" "$HOME" "$HISTFILE"')" \
      != "$work/home $work/home/history"; then
      die "run 2: zsh does not keep the work directory's HOME and HISTFILE, so it was not run"
    fi
    shell=(zsh -f -i)
    # Empty prompts keep zsh's interactive prompts, which show the host name, out of the output.
    shell_env=(PS1= PS2= PROMPT_EOL_MARK=)
    echo "Run 2: the same block, with zsh -f -i, from the top of the copy"
  else
    echo "Run 2: the same block, with bash, from the top of the copy"
    echo "zsh not present: criterion 5's zsh half is slice A's manual proof"
  fi
  if ! run_block "$work/repo" "${shell_env[@]}" -- "${shell[@]}"; then
    show_block_output
    die "run 2: the block did not finish"
  fi
  show_block_output
  for x in controlplane "${nodes[@]}"; do
    if cmp -s "$work/run1/$x.yaml" "$c/generated/$x.yaml"; then
      ok "run 2 gave the same $x.yaml as run 1"
    else
      fail "run 2 gave a different $x.yaml from run 1"
    fi
  done
  if cmp -s "$work/run1/talosconfig" "$c/generated/talosconfig"; then
    fail "run 2 gave the same talosconfig as run 1, so it did not generate a new one"
  else
    ok "run 2 gave a new talosconfig (a new client certificate)"
  fi

}

# 3. The values, node by node, and where the subnets are set. Then the self-test.
check_values() {
  local values="$c/cilium/values.yaml" n want got
  echo "Values: each node's config against metadata.env"
  for n in "${nodes[@]}"; do check_node "$work/run1/$n.yaml" "$n" "$values"; done
  check_sources "$c"

  echo "Self-test: the same checks on the generator's output without the patches"
  talosctl gen config home-prod "$CLUSTER_ENDPOINT" --with-secrets "$work/plain.yaml" \
    --kubernetes-version "$KUBERNETES_VERSION" --output-types controlplane --output "$work/unpatched.yaml" > /dev/null
  mode=selftest
  red=()
  check_node "$work/unpatched.yaml" cp-01 "$values"
  check_sources "$c"
  mode=check
  want="$(printf '%s\n' "${selftest_red[@]}" | LC_ALL=C sort)"
  got="$(printf '%s\n' "${red[@]}" | LC_ALL=C sort)"
  if test "$want" = "$got"; then
    ok "self-test: without the patches, exactly the ${#selftest_red[@]} checks for the patched values fail"
  else
    fail "self-test: without the patches, expected exactly the ${#selftest_red[@]} checks for the patched" \
      "values to fail. Not failing: $(comm -23 <(echo "$want") <(echo "$got") | paste -s -d ';' -)." \
      "Failing too: $(comm -13 <(echo "$want") <(echo "$got") | paste -s -d ';' -)."
  fi
}

# 4. The refusals, each in a fresh clone of the copy, and the stop at a failing command.
check_refusals() {
  local rc=0 stub
  echo "Refusals: each must stop the block with its own reason and change nothing"
  r="$work/case"
  fresh_case
  mkdir "$work/outside"
  refusal "outside any repository" "inside the home-lab repository" "$work/outside"
  fresh_case
  sgit init -q "$work/other"
  refusal "in another repository" "inside the home-lab repository" "$work/other"
  fresh_case
  sgit -C "$r" rm -q --cached "$d/secrets.sops.yaml"
  sgit -C "$r" commit -q --no-verify -m "untrack the bundle"
  refusal "the bundle not committed" "is not committed" "$r"
  fresh_case
  printf 'edited: true\n' >> "$r/$d/secrets.sops.yaml"
  refusal "the bundle edited" "uncommitted changes" "$r"
  fresh_case
  printf 'EDITED="true"\n' >> "$r/$d/metadata.env"
  refusal "metadata.env edited" "uncommitted changes" "$r"
  fresh_case
  rm -rf "$r/$d/secrets"
  ln -s "$work/target" "$r/$d/secrets"
  refusal "secrets a symbolic link to a directory" "secrets is a symbolic link" "$r"
  fresh_case
  rm -rf "$r/$d/secrets"
  echo "a file" > "$r/$d/secrets"
  refusal "secrets a regular file" "secrets is not a directory" "$r"
  fresh_case
  rm -rf "$r/$d/secrets"
  mkfifo "$r/$d/secrets"
  refusal "secrets a FIFO" "secrets is not a directory" "$r"
  fresh_case
  rm "$r/$d/secrets/secrets.yaml"
  ln -s "$work/target" "$r/$d/secrets/secrets.yaml"
  refusal "secrets/secrets.yaml a symbolic link to a directory" "secrets.yaml is a symbolic link" "$r"
  fresh_case
  rm "$r/$d/secrets/secrets.yaml"
  ln -s "$work/target/file" "$r/$d/secrets/secrets.yaml"
  refusal "secrets/secrets.yaml a symbolic link to a file" "secrets.yaml is a symbolic link" "$r"
  fresh_case
  rm "$r/$d/secrets/secrets.yaml"
  ln -s "$work/target/missing" "$r/$d/secrets/secrets.yaml"
  refusal "secrets/secrets.yaml a dangling symbolic link" "secrets.yaml is a symbolic link" "$r"
  fresh_case
  rm "$r/$d/secrets/secrets.yaml"
  mkdir "$r/$d/secrets/secrets.yaml"
  echo inside > "$r/$d/secrets/secrets.yaml/file"
  refusal "secrets/secrets.yaml a directory" "secrets.yaml is a directory" "$r"
  fresh_case
  # A stub talosctl that reports another version and records every other call.
  mkdir -p "$work/stub"
  : > "$work/stub/calls"
  # shellcheck disable=SC2016
  stub='#!/bin/sh\nif test "$1" = version; then printf "Client:\\nTalos v1.15.0\\n"; exit 0; fi\necho "$*" >> "%s"\n'
  # shellcheck disable=SC2059
  printf "$stub" "$work/stub/calls" > "$work/stub/talosctl"
  chmod 0755 "$work/stub/talosctl"
  refusal "talosctl reports v1.15.0" "talosctl is not" "$r" PATH="$work/stub:$PATH"
  if grep -q '^gen' "$work/stub/calls"; then
    fail "refusal, talosctl reports v1.15.0: the block still ran talosctl gen"
  fi
  fresh_case
  refusal "a wrong age key" "did not decrypt" "$r" SOPS_AGE_KEY_FILE="$work/wrong-age.txt"
  fresh_case
  head -c 300 "$r/$d/secrets.sops.yaml" > "$work/truncated"
  cat "$work/truncated" > "$r/$d/secrets.sops.yaml"
  sgit -C "$r" commit -q --no-verify -a -m "truncate the bundle"
  refusal "a truncated committed bundle" "did not decrypt" "$r"
  # A stub mv that fails to replace secrets/secrets.yaml, as mv does when the file can't be replaced
  # (an immutable file, say). Every other move goes to the real mv.
  fresh_case
  mkdir -p "$work/stub-mv"
  # shellcheck disable=SC2016
  stub='#!/bin/sh\nfor a; do last="$a"; done\nif test "$last" = secrets/secrets.yaml; then\n'
  stub+='  echo "mv: cannot replace secrets/secrets.yaml (a stub)" >&2\n  exit 1\nfi\nexec "%s" "$@"\n'
  # shellcheck disable=SC2059
  printf "$stub" "$(command -v mv)" > "$work/stub-mv/mv"
  chmod 0755 "$work/stub-mv/mv"
  refusal "secrets/secrets.yaml cannot be replaced (a stub mv fails)" "could not be replaced" "$r" \
    PATH="$work/stub-mv:$PATH"

  # The block stops at a failing command: cp-02's config fails validation (a fixed hostname needs
  # auto: "off"), so cp-03's is never written.
  fresh_case
  grep -v '^auto:' "$r/$d/nodes/cp-02.yaml" > "$work/cp-02.yaml"
  cat "$work/cp-02.yaml" > "$r/$d/nodes/cp-02.yaml"
  sgit -C "$r" commit -q --no-verify -a -m "an invalid cp-02 patch"
  run_block "$r" -- bash || rc=$?
  if test "$rc" != 0 && ! test -e "$r/$d/generated/cp-03.yaml"; then
    ok "stop: an invalid committed nodes/cp-02.yaml stops the block (rc $rc), and cp-03.yaml is not written"
  elif test "$rc" != 0; then
    fail "stop: an invalid committed nodes/cp-02.yaml stopped the block (rc $rc), but cp-03.yaml was written"
  else
    fail "stop: an invalid committed nodes/cp-02.yaml did not stop the block (rc 0)"
  fi
}

main() {
  prepare
  make_copy
  find_blocks
  run_twice
  check_values
  check_refusals
  finished=yes
  if test "$failures" -gt 0; then
    echo "$me: $failures checks failed" >&2
    exit 1
  fi
  echo "$me: every check passed"
}

# main runs in a new bash whose environment holds only PATH, TMPDIR and RUNNER_TEMP from the
# caller's, so nothing else the caller exports reaches git, sops, talosctl or the block: not
# GIT_DIR or GIT_INDEX_FILE, which git sets for its hooks and which would point the copy's git at
# the caller's repository; not SOPS_*, which would steer sops; not HOME, BASH_ENV or an exported
# function.
if test "${BASH_SOURCE[0]}" = "$0"; then
  exec env -i PATH="$PATH" ${TMPDIR:+"TMPDIR=$TMPDIR"} ${RUNNER_TEMP:+"RUNNER_TEMP=$RUNNER_TEMP"} \
    "$BASH" -c 'source "$1"; main' "$me" "$0"
fi
