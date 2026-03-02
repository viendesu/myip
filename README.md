# myip

Dead simple server that will just return your IP address.

## Building

```bash
# With Nix
nix build

# With Cargo
cargo build --release
```

## Configuration

Configuration is done via environment variables:

| Variable         | Required     | Description                                                                                |
|------------------|--------------|--------------------------------------------------------------------------------------------|
| `MYIP_LISTEN_V4` | One of V4/V6 | IPv4 address and port to listen on (e.g., `0.0.0.0:1234`)                                  |
| `MYIP_LISTEN_V6` | One of V4/V6 | IPv6 address and port to listen on (e.g., `[::]:1234`)                                     |
| `MYIP_HUMANE`    | No           | `true` (default): return IP as text; `false`: return raw bytes (4 for IPv4, 16 for IPv6)   |
| `MYIP_MODE`      | No           | `dontwait` (default): single write attempt; `writeall`: retry until full buffer is written |

You must set exactly one of `MYIP_LISTEN_V4` or `MYIP_LISTEN_V6`. Set to `none` to explicitly disable.

## Usage

### Standalone

```bash
# Start the server
MYIP_LISTEN_V4=0.0.0.0:3000 ./myip

# Query your IP
nc myip.example.com 3000
# Output: 203.0.113.42

# Or with telnet
telnet myip.example.com 3000

# Or through any browser, just visit the running server and usually your IP will be displayed, despite the fact that returned text is not valid HTTP.

# Raw binary output (for scripts)
MYIP_LISTEN_V4=0.0.0.0:3000 MYIP_HUMANE=false ./myip
```

### NixOS Module

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    myip = {
      url = "github:youruser/myip";  # adjust URL
      inputs.nixpkgs.follows = "nixpkgs";
      #inputs.rust-overlay.follows = "rust-overlay";
      # ^ The build is done through rust-overlay, override if you want.
    };
  };
}
```

Apply overlays and import the module:

```nix
{ inputs, ... }:
{
  nixpkgs.overlays = [
    inputs.myip.overlays.default
  ];

  imports = [ inputs.myip.nixosModules.default ];
}
```

Configure instances:

```nix
{
  services.myip = {
    # Defaults for all instances
    enable = true;
    autostart = true;

    # IPv4 instances
    instances.v4 = {
      human = {
        listen = "0.0.0.0:3000";
      };
      machine = {
        listen = "0.0.0.0:3001";
        humane = false;
      };
    };

    # IPv6 instances
    instances.v6 = {
      human = {
        listen = "[::]:3000";
      };
    };
  };
}
```

This creates three systemd services: `myip-v4-human`, `myip-v4-machine`, and `myip-v6-human`.

#### Module Options

**Global options** (defaults for all instances):

| Option      | Type    | Default     | Description                              |
|-------------|---------|-------------|------------------------------------------|
| `enable`    | bool    | `true`      | Whether to enable instances by default   |
| `autostart` | bool    | `true`      | Whether instances start on boot by default |
| `package`   | package | `pkgs.myip` | The myip package to use                  |

**Per-instance options** (`services.myip.instances.v4.<name>` or `services.myip.instances.v6.<name>`):

| Option      | Type                           | Default     | Description                    |
|-------------|--------------------------------|-------------|--------------------------------|
| `enable`    | bool                           | inherited   | Whether to create this instance |
| `autostart` | bool                           | inherited   | Whether to start on boot       |
| `listen`    | string                         | required    | Address and port to listen on  |
| `mode`      | null or "dontwait"/"writeall"  | `null`      | Write mode                     |
| `humane`    | null or bool                   | `null`      | Human-readable output          |

## License

MIT
