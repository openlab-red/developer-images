#!/bin/bash

# Kubedock setup script meant to be run from the entrypoint script.

LOCAL_BIN=/home/user/.local/bin
ORIGINAL_PODMAN_PATH=${ORIGINAL_PODMAN_PATH:-"/usr/bin/podman.orig"}
PODMAN_WRAPPER_PATH=${PODMAN_WRAPPER_PATH:-"/usr/bin/podman.wrapper"}

mkdir -p "${LOCAL_BIN}"

if [ "${KUBEDOCK_ENABLED:-false}" = "true" ]; then
  echo
  echo "Kubedock is enabled (env variable KUBEDOCK_ENABLED is set to true)."

  SECONDS=0
  KUBEDOCK_TIMEOUT=${KUBEDOCK_TIMEOUT:-10}
  until [ -f $KUBECONFIG ]; do
    if ((SECONDS > KUBEDOCK_TIMEOUT)); then
      break
    fi
    echo "Kubeconfig doesn't exist yet. Waiting..."
    sleep 1
  done

  if [ -f $KUBECONFIG ]; then
    echo "Kubeconfig found."

    echo "Fix Kubeconfig permission."
    attempts=5
    while [ $attempts -gt 0 ]; do
        if [ -f /home/user/.kube/config ]; then
            chmod 600 /home/user/.kube/config
            break
        else
            echo "Config file not found. Retrying..."
            attempts=$((attempts - 1))
            sleep 5
        fi
    done

    if [ -z "$KUBEDOCK_PARAMS" ]; then
      KUBEDOCK_PARAMS="--reverse-proxy --kubeconfig $KUBECONFIG"
      if [ -n "$REQUEST_CPU" ] && [ -n "$REQUEST_MEMORY" ]; then
        KUBEDOCK_PARAMS="$KUBEDOCK_PARAMS --request-cpu=$REQUEST_CPU --request-memory=$REQUEST_MEMORY"
      fi
      if [ -n "$REAPER_KEEPMAX" ]; then
        KUBEDOCK_PARAMS="$KUBEDOCK_PARAMS --reapmax=$REAPER_KEEPMAX"
      fi
    fi

    echo "Starting kubedock with params \"${KUBEDOCK_PARAMS}\"..."

    kubedock server ${KUBEDOCK_PARAMS} >/tmp/kubedock.log 2>&1 &

    echo "Done."

    echo "Replacing podman with podman-wrapper..."

    ln -f -s "${PODMAN_WRAPPER_PATH}" "${LOCAL_BIN}/podman"

    export TESTCONTAINERS_RYUK_DISABLED="true"
    export TESTCONTAINERS_CHECKS_DISABLE="true"

    echo "Done."
    echo
  else
    echo "Could not find Kubeconfig at $KUBECONFIG"
    echo "Giving up..."
  fi
else
  echo
  echo "Kubedock is disabled. It can be enabled with the env variable \"KUBEDOCK_ENABLED=true\""
  echo "set in the workspace Devfile or in a Kubernetes ConfigMap in the developer namespace."
  echo
  ln -f -s "${ORIGINAL_PODMAN_PATH}" "${LOCAL_BIN}/podman"
fi
