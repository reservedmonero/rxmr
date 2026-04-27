# Public rXMR Node Guide

rXMR can run as a private CPU miner, but public peers make the network easier to discover and sync.

## Minimum host expectations

- 64-bit Linux host
- at least 2 CPU cores
- at least 4 GiB RAM
- stable public IPv4 preferred

## Install

Use the tagged-release installer when one is available:

```bash
curl -fsSLO https://github.com/happybigmtn/rXMR/releases/latest/download/install.sh
less install.sh
bash install.sh --add-path
```

The installer prefers the newest release that includes a matching platform tarball, rather than blindly trusting `releases/latest`.
On Linux, source fallback now prefers host-linked binaries (`STATIC=OFF`) and refuses to leave behind binaries with unresolved runtime libraries.

If `rxmrd` is already installed, the systemd path is:

```bash
sudo rxmr-public-apply --address YOUR_RXMR_ADDRESS --enable-now
```

That is the recommended public onboarding path. It converges the host onto the public-node service, mining override, and a final health check in one command.

## Required config

The public-node template installs `/etc/rxmr/rxmr.conf` with:

```ini
p2p-bind-ip=0.0.0.0
p2p-bind-port=18880
rpc-bind-ip=127.0.0.1
rpc-bind-port=18881
zmq-rpc-bind-port=18882
```

Keep RPC bound to localhost unless you are intentionally exposing a restricted remote node behind your own auth and firewall.

## Open the public port

Expose `18880/TCP` on the host and cloud firewall:

- `sudo ufw allow 18880/tcp`
- verify your VPS provider security group also allows inbound `18880/TCP`

## Verify health

After startup:

```bash
rxmr-doctor --json --strict --expect-public
curl -fsS http://127.0.0.1:18881/get_info
```

Healthy public peers should show nonzero outbound peers and eventually nonzero inbound peers.

## Enable persistent mining

Once the public node is installed:

```bash
sudo rxmr-install-public-miner --address YOUR_RXMR_ADDRESS --enable-now
```

By default the helper uses `CPU count - 1` threads and sets `Nice=19`.

To converge a new host in one step and fail loudly if health is still wrong:

```bash
sudo rxmr-public-apply --address YOUR_RXMR_ADDRESS --enable-now --strict
```

To remove mining and keep the node online:

```bash
sudo rxmr-install-public-miner --remove --enable-now
```
