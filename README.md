# sparky

My ASUS Ascent GB10, the DGX Spark in a different case, arrived last Friday
and only by a stroke of luck because I serrendipitously caught the delivery driver
walking back to his truck with a single box.

I picked it up because Big Ai, you know...
I wanted freedom to run models as much as I want locally.
Let me tell you, this was

The stack

1. dgx spark
1. k3s
1. llama-cpp / vllm
1. agents
1. scion
1. more kubernetes


## dgx spark by another name would smell as sweet

On first boot, `sparky` looks just like starting any linux distro with grub.
I had only attached the monitor at this point, I was intending to use this box remotely.
It ended up in a graphical linux setup screen, prompting me to attach a keyboard.
The box has 3 usb-c ports, but I only have usb-2 keyboards laying around.
After digging around, I found an adapter, plugged things in and was ready to go, or so I thought.
The next step was asking for a mouse, no way to skip, like what? I only need SSH, text only is fine...
After some more digging around, I was able to finish the new user setup on a fresh linux machine.

It then proceeded to do some updating before really starting up.
I logged in without thinking much only to realize this was a full linux desktop.
It's been quite a while and I guess I'm re-evaluating *The Year of the Linux Desktop* circa 2026, we'll see.

I was underwealmed by the installed software out-of-the-box.
There was still a number of things to install to do any real ai things.

- nvm / node / go / uv (needed to install other tools)
- huggingface (like really...)
- llama-cpp / vllm / ollama (no way to run models, common ways)
- agent tools (no claude, opencode, or anything)

My initial steps were something like:

*note, you'll need to relog after some of these as well as update your path*

```sh
# Do another upgrade & reboot
sudo apt update && sudo apt upgrade
sudo reboot now

# setup ssh keys / authorized_keys
ssh-keygen
vim .ssh/authorized_keys

# passwordless sudo
sudo visudo /etc/sudoers

# sudoless docker
sudo usermod -aG docker $USER

# set a nice hostname
sudo vim /etc/hostname

# zsh & oh-my-zsh
sudo apt install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
usermod -s /bin/zsh $USER # not normally needed, but I seemed to on this machine
omz theme set dst
```

The language steps:

```sh
# NVM & Node
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
nvm install 24

# Go
wget https://go.dev/dl/go1.26.2.linux-arm64.tar.gz
sudo tar -C /usr/local -xzf go1.26.2.linux-arm64.tar.gz

# UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Huggingface
curl -LsSf https://hf.co/cli/install.sh | bash
hf auth login

# latest git (for worktrees)
sudo add-apt-repository ppa:git-core/ppa
sudo apt update; sudo apt upgrade git
```

## k3s

Install & setup k3s

```sh
curl -sfL https://get.k3s.io | sh - 
mkdir .kube
sudo cp /etc/rancher/k3s/k8s.yaml .kube/config
sudo chown $USER:$USER .kube/config
kubectl get nodes
```

## serving models

Currently I'm serving the models outside of kubernetes on the host.
Unsloth does a good job creating quants, so I'm using their models.
I initially became interested in local models after trying gemma-4 on a cpu.
Then qwen-3.6 came out and it was even better, but neither was fast enough
for interactive coding sessions, that was until sparky came in.


### llama-cpp setup

I'm mainly using llama-cpp, makes it the easier to use Unsloth's quants.
They are now using a dynamic method that uses evals to decide which weights to shrink.

```sh
# clone repo
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp

# build tools
cmake -B build -DGGML_CUDA=ON -DLLAMA_OPENSSL=ON
cmake --build build --config Release -j --clean-first

# benchmark model (also downloads it)
./build/bin/llama-bench -hf unsloth/Qwen3.6-35B-A3B-GGUF:Q8_K_XL -p 4096 -n 512

# serve model
./build/bin/llama-server -hf unsloth/Qwen3.6-35B-A3B-GGUF:Q8_K_XL --host 0.0.0.0 --port 8080
```

Check out the `./scripts/llama.sh` to download and benchmark a set of models.

### vllm setup

There is currently missing steps from the docs,
see [this github issue](https://github.com/vllm-project/vllm/issues/31018).

__Warning__, running the same unsloth model crashed `sparky`,
I think because it uses the full model and OOMs.
More to figure out here, there should be a proper set of flags.

```sh
# setup .vllm
uv venv .vllm --python 3.12 --seed --managed-python
source .vllm/bin/activate

# install vllm and deps
uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cu130
uv pip install -U vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly/cu130
export TORCH_CUDA_ARCH_LIST=12.1a

# serve model
vllm serve unsloth/Qwen3.6-35B-A3B --host 0.0.0.0 --port 8080
```


## agents

Install the agents

```sh
curl -fsSL https://claude.ai/install.sh | bash
npm i -g opencode-ai
npm i -g @google/gemini-cli
npm i -g @openai/codex
```

Fake the models

*note, this only works with claude and opencode, litellm can be used for the other two alledgedly*

```sh
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_BASE_URL=http://localhost:8080

claude --model Qwen3.6-35B-A3B
opencode --model llama.cpp/Qwen3.6-35B-A3B
```

*note:* `~/.config/opencode/opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "Qwen3.6-35B-A3B": {
          "name": "Qwen3.6-35B-A3B (local)",
          "limit": {
            "context": 128000,
            "output": 65536
          }
        }
      }
    }
  }
}
```



## scion

Scion is a new Google Cloud open source project for running async agents.

- https://googlecloudplatform.github.io/scion/overview/
- https://github.com/GoogleCloudPlatform/scion

### Setup

Install Scion

```sh
git clone https://github.com/GoogleCloudPlatform/scion
cd scion
go install ./cmd/scion
```

Custom buildkitd config

```toml
[registry."host.bridge.internal:5000"]
  http = true
  insecure = true
[registry."localhost:5000"]
  http = true
  insecure = true
```

Custom buildx setup (for local registry)

```sh
docker buildx create --name scion-builder --driver-opt network=host --config buildkitd.toml --use
```

Run the local registry

```sh
docker run -d registry:3 -p 5000:5000 registry
```

Build the scion images

```sh
./image-build/scripts/build-images.sh --registry localhost:5000 --target all --push
```

Scion init

```sh
scion init --machine
vim ~/.scion/settings.yaml
```

Add or change the following

```yaml
# ...

default_harness_config: claude # opencode

profiles:
  local:
    runtime: docker
    env:
      ANTHROPIC_AUTH_TOKEN: local
      ANTHROPIC_BASE_URL: http://172.17.0.1:8080
  remote:
    runtime: kubernetes
    env:
      ANTHROPIC_AUTH_TOKEN: local
      ANTHROPIC_BASE_URL: http://llama-cpp:8080

runtimes:
  # ...
  kubernetes:
    type: kubernetes
    gke: false
    namespace: scion-agents

```

### run an agent

```sh
# create a new git repo
mkdir hack && cd hack && git init

# start some work
scion start hello-go \
  --no-auth \
  --harness opencode \
  "create a hello world in Go that takes an optional first arg" 

# inspect the work
scion list
scion look hello-go
scion attach hello-go

# you probably have a new hello.go file
```


### scion agents running on kubernetes

Prepare kubernetes

```sh
# create the agent namespace
kubectl create ns scion-agents

# update the host IP address
vim ./util/llama-cpp.yaml

# from this repo, service for external (host) llama.cpp server
kubectl apply -n scion-agents -f ./util/llama-cpp.yaml
```

Run a remote agent

```sh
# start some work
scion start hello-py \
  --no-auth \
  --profile remote \
  --harness opencode \
  "create a hello world in Python that takes an optional first arg" 

# inspect the work
scion list
scion look hello-py
scion attach hello-py

# you have to explicitly call sync
scion sync from hello-py --profile remote
```


## more kubernetes

We can run more on kubernetes
