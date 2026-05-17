# How to set up Scion with k3s

---

## Prerequisites

1. k3s running — either installed locally or a remote cluster
2. kubectl configured pointing to your k3s cluster (i.e., `~/.kube/config` works)
3. Scion built/installed — `go install github.com/GoogleCloudPlatform/scion/cmd/scion@latest` or build from source
4. Agent images built — Scion needs container images for the agents (Claude Code, Gemini CLI, etc.)

---

## Step 1: Verify k3s connectivity

```bash
kubectl cluster-info
kubectl get nodes
```

This must work before Scion can use k3s.

---

## Step 2: Configure Scion to use Kubernetes runtime

In your project's `.scion/settings.json` (or `~/.scion/settings.json` for global), add a Kubernetes runtime profile:

```json
{
  "runtimes": {
    "kubernetes": {
      "type": "kubernetes",
      "namespace": "scion-agents",
      "context": "k3s"
    }
  }
}
```

### Key fields

| Field       | Description                                              |
|-------------|----------------------------------------------------------|
| `type`      | `kubernetes` (or `k8s`, `remote`)                        |
| `namespace` | K8s namespace for agent pods (default: `default`)        |
| `context`   | kubeconfig context name (optional, defaults to current)  |

You can also override per-profile in the profiles section, or use the `--runtime kubernetes` flag on the CLI.

---

## Step 3: Build your agent images

Scion doesn't ship pre-built images. You need to build them first — see the build docs. Typically:

```bash
# From the scion repo root
make build
# or follow the build-container-images guide
```

The images need to include the agent harness (e.g., claude-code, gemini-cli) and sciontool.

---

## Step 4: Initialize and run

```bash
# In your project directory
scion init

# Start an agent on k3s
scion start debug "Help me with X" --runtime kubernetes --attach
```

Or set `kubernetes` as the default runtime so you don't need `--runtime` every time (Step 2).

---

## What happens under the hood

When you run an agent on k3s, Scion:

1. Creates a Pod with your agent image
2. Syncs your workspace (tar streaming into the pod's `/workspace` EmptyDir)
3. Syncs your home dir (dotfiles, credentials) into `/home/scion/`
4. Creates K8s Secrets for agent credentials (API keys, auth files)
5. Waits for the pod to be Running, then signals the startup gate
6. Agent runs inside the pod with tmux sessions (agent + shell windows)

You can manage agents with the same CLI commands:

```bash
scion list          # List active agents (queries K8s pods)
scion attach <name> # Attach to agent's tmux session
scion logs <name>   # Stream pod logs
scion stop <name>   # Delete the pod
scion delete <name> # Clean up pod + secrets
```

---

## k3s-specific notes

- k3s is fully compatible with standard Kubernetes APIs, so Scion's k8s runtime works out of the box
- k3s uses a single binary and embedded etcd — no extra setup needed
- If you're running k3s with a custom kubeconfig path, set `KUBECONFIG` env var
- k3s defaults to containerd — make sure your agent images are pullable from the node's container runtime
- For GPU support, k3s needs the NVIDIA device plugin installed separately; you can specify GPU resources via `config.Kubernetes.Resources`
