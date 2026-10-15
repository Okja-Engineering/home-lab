#!/usr/bin/env bash
# Check the Cilium Helm values: render the pinned chart with them and check what the cluster would
# get. The cilium-values job in .github/workflows/validate.yml runs it on every pull request. It runs
# on a workstation too.
#
#   scripts/cilium-values-check.sh
#
# It downloads the chart at CILIUM_VERSION (platform/talos/clusters/home-prod/metadata.env), stops
# unless the file's SHA-256 is CILIUM_CHART_SHA256, and renders that file with
# platform/talos/clusters/home-prod/cilium/values.yaml, as it is in the working tree. Then it checks
# the values file and the render (the checks are in check_render below). It also renders the chart's
# defaults and runs the same checks on them, which must fail exactly the checks for the values the
# file sets.
# It prints "ok <check>" or "FAIL <check>: expected ..., got ...". It never prints the render, which
# holds generated keys.
#
# Needs bash 5 or later, git, helm, yq (v4) and sha256sum, and network access to helm.cilium.io.
# helm runs with its own empty configuration, cache and data directories. Exit status: 0 when every
# check passed, 1 when one failed, 2 when bash is older than 5 or a tool is missing.
test "${BASH_VERSINFO[0]:-0}" -ge 5 || { echo "cilium-values-check: needs bash 5 or later" >&2; exit 2; }
set -euo pipefail

me=cilium-values-check

# Run rather than sourced, this shell goes no further: main runs in a new bash whose environment
# holds only PATH, TMPDIR and RUNNER_TEMP from the caller's, so nothing else the caller exports
# reaches git, helm or yq: not GIT_DIR or GIT_WORK_TREE, which would make git find another
# checkout; not HELM_*, KUBECONFIG or HOME, which would give helm the user's configuration; and the
# new bash gets no BASH_ENV or exported function. The new bash sources the file this shell opened
# (BASH_SOURCE), made absolute, so that no PATH lookup can bring in another copy. Handing over
# here, before anything is defined, means that a run can't end without main: a run found on PATH,
# or a truncated copy of this file, fails instead of passing unchecked.
if ! (return 0 2> /dev/null); then
  case "${BASH_SOURCE[0]}" in /*) self="${BASH_SOURCE[0]}" ;; *) self="$PWD/${BASH_SOURCE[0]}" ;; esac
  exec env -i PATH="$PATH" ${TMPDIR:+"TMPDIR=$TMPDIR"} ${RUNNER_TEMP:+"RUNNER_TEMP=$RUNNER_TEMP"} \
    "$BASH" -c 'source "$1"; main' "$me" "$self"
fi

d=platform/talos/clusters/home-prod

# The metadata.env values this script reads (read_metadata), and no others.
metadata_keys=(CILIUM_VERSION CILIUM_CHART_SHA256 POD_SUBNETS)

# Every container in the render, with the capabilities it adds, sorted. Any other container fails.
capabilities=(
  "cilium-envoy/cilium-envoy: NET_ADMIN,SYS_ADMIN"
  "cilium-operator/cilium-operator: none"
  "cilium/apply-sysctl-overwrites: SYS_ADMIN,SYS_CHROOT,SYS_PTRACE"
  "cilium/cilium-agent: CHOWN,DAC_OVERRIDE,FOWNER,IPC_LOCK,KILL,NET_ADMIN,NET_RAW,SETGID,SETUID,SYS_ADMIN,SYS_RESOURCE"
  "cilium/clean-cilium-state: NET_ADMIN,SYS_ADMIN,SYS_RESOURCE"
  "cilium/config: NET_ADMIN"
  "cilium/install-cni-binaries: none"
)

# Every container in the render, with what it runs (its command and arguments, white space
# collapsed) and the names of its environment variables, sorted. The agent and the operator take an
# option from a flag or a CILIUM_ variable before the cilium-config ConfigMap that the checks below
# read (viper's order), and the config container, which builds the agent's configuration, takes
# its sources and the API server as flags in its command. So any other command, argument or
# variable fails: extraArgs, extraEnv or daemon.configSources could otherwise undo a checked value.
# ${BIN_PATH} and the operator's $(CILIUM_DEBUG) are not the shell's to expand: single quotes.
# shellcheck disable=SC2016
commands=(
  "cilium-envoy/cilium-envoy: /usr/bin/cilium-envoy-starter -- -c /var/run/cilium/envoy/bootstrap-config.json --base-id 0 --log-level info; CILIUM_K8S_NAMESPACE,K8S_NODE_NAME,KUBERNETES_SERVICE_HOST,KUBERNETES_SERVICE_PORT"
  'cilium-operator/cilium-operator: cilium-operator-generic --config-dir=/tmp/cilium/config-map --debug=$(CILIUM_DEBUG); CILIUM_DEBUG,CILIUM_K8S_NAMESPACE,K8S_NODE_NAME,KUBERNETES_SERVICE_HOST,KUBERNETES_SERVICE_PORT'
  'cilium/apply-sysctl-overwrites: bash -ec cp /usr/bin/cilium-sysctlfix /hostbin/cilium-sysctlfix; nsenter --mount=/hostproc/1/ns/mnt "${BIN_PATH}/cilium-sysctlfix"; rm /hostbin/cilium-sysctlfix; BIN_PATH'
  "cilium/cilium-agent: cilium-agent --config-dir=/tmp/cilium/config-map; CILIUM_CLUSTERMESH_CONFIG,CILIUM_K8S_NAMESPACE,GOMEMLIMIT,K8S_NODE_NAME,KUBERNETES_SERVICE_HOST,KUBERNETES_SERVICE_PORT,KUBE_CLIENT_BACKOFF_BASE,KUBE_CLIENT_BACKOFF_DURATION"
  "cilium/clean-cilium-state: /init-container.sh; CILIUM_ALL_STATE,CILIUM_BPF_STATE,KUBERNETES_SERVICE_HOST,KUBERNETES_SERVICE_PORT,WRITE_CNI_CONF_WHEN_READY"
  "cilium/config: cilium-dbg build-config; CILIUM_K8S_NAMESPACE,K8S_NODE_NAME,KUBERNETES_SERVICE_HOST,KUBERNETES_SERVICE_PORT"
  "cilium/install-cni-binaries: /install-plugin.sh; "
)

# The checks the chart's defaults must fail, and no others: the values the file exists to set.
selftest_red=(
  "values.yaml sets ipv4.enabled true" "values.yaml sets ipv6.enabled false"
  "ipam" "kube-proxy-replacement" "cgroup-root"
  "routing-mode" "auto-direct-node-routes" "ipv4-native-routing-cidr is POD_SUBNETS"
  "no metrics listener"
  "agent KUBERNETES_SERVICE_HOST" "agent KUBERNETES_SERVICE_PORT" "the API server only through KubePrism"
  "every container and its added capabilities, exactly"
  "every container's command, arguments and environment variable names, exactly" "no privileged container"
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

# eq NAME EXPECTED GOT: the check passes only when EXPECTED is neither empty nor null and GOT equals
# it.
eq() {
  local name="$1" want="$2" got="$3"
  if test -n "$want" && test "$want" != null && test "$want" = "$got"; then
    if test "$mode" = check; then echo "ok $name"; fi
    return 0
  fi
  red+=("$name")
  if test "$mode" = selftest; then
    echo "SELFTEST-RED $name: expected ${want:-(empty)}, got ${got:-(empty)}"
  else
    fail "$name: expected ${want:-(empty)}, got ${got:-(empty)}"
  fi
}

# q EXPRESSION FILE: yq over every document of the file. Prints nothing when yq fails, which fails
# the check.
q() {
  local out
  out="$(yq ea "$1" "$2" < /dev/null 2> /dev/null)" || out=""
  printf '%s' "$out"
}

# Every container of every workload: Pods, the controllers' pod templates, and CronJobs'.
# shellcheck disable=SC2016
workload_containers='
  select(.kind == "Pod" or .kind == "DaemonSet" or .kind == "Deployment" or .kind == "StatefulSet" or
    .kind == "ReplicaSet" or .kind == "Job" or .kind == "CronJob") |
  .metadata.name as $w |
  (.spec.jobTemplate.spec.template.spec // .spec.template.spec // .spec) |
  ((.initContainers // []) + (.containers // []) + (.ephemeralContainers // [])) | .[] |
  .workload = $w'

# check_render RENDER VALUES
check_render() {
  local r="$1" v="$2" config='[select(.kind == "ConfigMap" and .metadata.name == "cilium-config")] | .[0].data'

  # Both equal the chart's defaults, so only the file shows the decision (ADR-016).
  eq "values.yaml sets ipv4.enabled true" true "$(q '.ipv4.enabled' "$v")"
  eq "values.yaml sets ipv6.enabled false" false "$(q '.ipv6.enabled' "$v")"

  eq "enable-ipv4" true "$(q "$config | .[\"enable-ipv4\"]" "$r")"
  eq "enable-ipv6" false "$(q "$config | .[\"enable-ipv6\"]" "$r")"
  eq "ipam" kubernetes "$(q "$config | .ipam" "$r")"
  eq "kube-proxy-replacement" true "$(q "$config | .[\"kube-proxy-replacement\"]" "$r")"
  eq "cgroup-root" /sys/fs/cgroup "$(q "$config | .[\"cgroup-root\"]" "$r")"
  eq "routing-mode" native "$(q "$config | .[\"routing-mode\"]" "$r")"
  eq "auto-direct-node-routes" true "$(q "$config | .[\"auto-direct-node-routes\"]" "$r")"
  eq "ipv4-native-routing-cidr is POD_SUBNETS" "$POD_SUBNETS" "$(q "$config | .[\"ipv4-native-routing-cidr\"]" "$r")"

  # No metrics listener, on any port. Each one names Prometheus or metrics somewhere in the render:
  # a serve address or an enable flag in cilium-config, a prometheus.io annotation, a port named
  # prometheus or *-metrics, Envoy's metrics listener, or an argument. The only such name these
  # values leave is cilium-config's metrics-sampling-interval, which is not a listener; finding it
  # is the positive control, showing that the search reads every document.
  eq "no metrics listener" metrics-sampling-interval \
    "$(q '[select(.kind != "Secret") | ((.. | select(tag == "!!map") | keys | .[]), (.. | select(tag == "!!str"))) |
      match("(?i)[^ \"]*(prometheus|metric)[^ \"]*"; "g") | .string] | unique | sort | join(" ")' "$r")"

  eq "agent KUBERNETES_SERVICE_HOST" localhost \
    "$(q '[select(.kind == "DaemonSet" and .metadata.name == "cilium") | .spec.template.spec.containers[] |
      select(.name == "cilium-agent") | .env // [] | .[] | select(.name == "KUBERNETES_SERVICE_HOST") | .value] |
      join(" ")' "$r")"
  eq "agent KUBERNETES_SERVICE_PORT" 7445 \
    "$(q '[select(.kind == "DaemonSet" and .metadata.name == "cilium") | .spec.template.spec.containers[] |
      select(.name == "cilium-agent") | .env // [] | .[] | select(.name == "KUBERNETES_SERVICE_PORT") | .value] |
      join(" ")' "$r")"
  # The agent and the operator take the API server from a kubeconfig path, then from API server URLs,
  # and only when both are unset from KUBERNETES_SERVICE_HOST and _PORT, which the two checks above
  # pin to KubePrism. Every source names itself in the render: k8s-kubeconfig-path and
  # k8s-api-server-urls as cilium-config keys, flags or CILIUM_ variables, and kubeConfigPath's
  # kube-config volume. Only the KubePrism pair may be found; finding it is the positive control.
  eq "the API server only through KubePrism" "KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT" \
    "$(q '[select(.kind != "Secret") | ((.. | select(tag == "!!map") | keys | .[]), (.. | select(tag == "!!str"))) |
      match("(?i)[^ \"]*(kubernetes[-_]service[-_](host|port)|k8s[-_]api[-_]server|kube[-_]?config)[^ \"]*"; "g") |
      .string] | unique | sort | join(" ")' "$r")"

  eq "every container and its added capabilities, exactly" "$(printf '%s\n' "${capabilities[@]}" | paste -s -d ';' -)" \
    "$(q "[$workload_containers | .workload + \"/\" + .name + \": \" +
      ([((.securityContext.capabilities.add // []) | sort | join(\",\")), \"none\"] | map(select(. != \"\")) | .[0])] |
      sort | join(\";\")" "$r")"
  eq "every container's command, arguments and environment variable names, exactly" \
    "$(printf '%s\n' "${commands[@]}" | paste -s -d '|' -)" \
    "$(q "[$workload_containers | .workload + \"/\" + .name + \": \" +
      (((.command // []) + (.args // [])) | join(\" \") | sub(\"\\s+\"; \" \") | sub(\" \$\"; \"\")) + \"; \" +
      ([(.env // [])[] | .name] | sort | join(\",\"))] | sort | join(\"|\")" "$r")"
  eq "no privileged container" 0 \
    "$(q "[$workload_containers | select(.securityContext.privileged == true)] | length" "$r")"

  eq "operator replicas" 2 \
    "$(q '[select(.kind == "Deployment" and .metadata.name == "cilium-operator")] | .[0].spec.replicas' "$r")"
}

# Set each of metadata_keys to its value in metadata.env, and set nothing else. The file is sourced
# in a subshell, and only these values come back, as data: no other name the file sets (one of this
# script's own, such as mode or failures, or PATH or IFS) reaches this script.
read_metadata() {
  local -a got
  local i
  mapfile -d '' -t got < <(
    source "$top/$d/metadata.env" > /dev/null
    for k in "${metadata_keys[@]}"; do printf '%s\0' "${!k-}" "${!k+set}"; done
  )
  for i in "${!metadata_keys[@]}"; do
    test "${got[2 * i + 1]-}" = set || { echo "$me: $d/metadata.env does not set ${metadata_keys[i]}" >&2; exit 1; }
    printf -v "${metadata_keys[i]}" '%s' "${got[2 * i]}"
  done
}

main() {
  local tool
  for tool in git helm yq sha256sum paste; do
    command -v "$tool" > /dev/null || { echo "$me: $tool is not on PATH" >&2; exit 2; }
  done
  top="$(git rev-parse --show-toplevel 2> /dev/null)" || { echo "$me: run this inside the repository" >&2; exit 1; }
  test -f "$top/$d/metadata.env" || { echo "$me: $d/metadata.env is missing" >&2; exit 1; }
  read_metadata
  local values="$top/$d/cilium/values.yaml"
  test -f "$values" || { echo "$me: $d/cilium/values.yaml is missing" >&2; exit 1; }
  if test -z "$CILIUM_VERSION" || test -z "$CILIUM_CHART_SHA256"; then
    echo "$me: CILIUM_VERSION and CILIUM_CHART_SHA256 must both be set in $d/metadata.env" >&2
    exit 1
  fi
  work="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/cilium-values.XXXXXX")"
  trap on_exit EXIT
  export HELM_CACHE_HOME="$work/helm/cache" HELM_CONFIG_HOME="$work/helm/config" HELM_DATA_HOME="$work/helm/data"

  local chart="$work/cilium-$CILIUM_VERSION.tgz"
  helm pull cilium --repo https://helm.cilium.io/ --version "$CILIUM_VERSION" --destination "$work"
  if ! printf '%s  %s\n' "$CILIUM_CHART_SHA256" "$chart" | sha256sum -c - > /dev/null; then
    die "chart digest: cilium-$CILIUM_VERSION.tgz does not match CILIUM_CHART_SHA256; nothing was rendered"
  fi
  ok "chart digest: cilium-$CILIUM_VERSION.tgz matches CILIUM_CHART_SHA256"

  if ! helm template cilium "$chart" --namespace kube-system -f "$values" \
    > "$work/render.yaml" 2> "$work/helm.err"; then
    cat "$work/helm.err"
    die "render: helm template failed with values.yaml"
  fi
  echo "Render: the chart with values.yaml"
  check_render "$work/render.yaml" "$values"

  echo "Self-test: the same checks on the chart's defaults (empty values)"
  : > "$work/empty.yaml"
  helm template cilium "$chart" --namespace kube-system -f "$work/empty.yaml" > "$work/defaults.yaml"
  mode=selftest
  red=()
  check_render "$work/defaults.yaml" "$work/empty.yaml"
  mode=check
  local want got
  want="$(printf '%s\n' "${selftest_red[@]}" | LC_ALL=C sort)"
  got="$(printf '%s\n' "${red[@]}" | LC_ALL=C sort)"
  if test "$want" = "$got"; then
    ok "self-test: on the chart's defaults, exactly the ${#selftest_red[@]} checks for the values the file sets fail"
  else
    fail "self-test: on the chart's defaults, expected exactly the ${#selftest_red[@]} checks for the values" \
      "the file sets to fail. Not failing: $(comm -23 <(echo "$want") <(echo "$got") | paste -s -d ';' -)." \
      "Failing too: $(comm -13 <(echo "$want") <(echo "$got") | paste -s -d ';' -)."
  fi

  finished=yes
  if test "$failures" -gt 0; then
    echo "$me: $failures checks failed" >&2
    exit 1
  fi
  echo "$me: every check passed"
}
