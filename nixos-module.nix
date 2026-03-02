{ config, lib, pkgs, ... }:

let
  cfg = config.services.myip;

  instanceModule = { name, config, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable this myip instance.";
      };

      autostart = lib.mkOption {
        type = lib.types.bool;
        default = cfg.autostart;
        description = "Whether to start this instance on boot.";
      };

      listen = lib.mkOption {
        type = lib.types.str;
        description = "Address and port to listen on.";
      };

      mode = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "dontwait" "writeall" ]);
        default = null;
        description = "Write mode: dontwait or writeall.";
      };

      humane = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to return IP as human-readable text or raw bytes.";
      };
    };
  };

  mkService = ipVersion: name: instanceCfg: lib.nameValuePair "myip-${ipVersion}-${name}" {
    description = "myip ${name} instance";
    wantedBy = lib.optionals instanceCfg.autostart [ "multi-user.target" ];
    after = [ "network.target" ];

    environment =
      { ${"MYIP_LISTEN_" + lib.toUpper ipVersion} = instanceCfg.listen; }
      // lib.optionalAttrs (instanceCfg.mode != null) { MYIP_MODE = instanceCfg.mode; }
      // lib.optionalAttrs (instanceCfg.humane != null) { MYIP_HUMANE = if instanceCfg.humane then "true" else "false"; };

    serviceConfig = {
      ExecStart = "${cfg.package}/bin/myip";
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  mkServices = ipVersion: instances:
    lib.mapAttrsToList (mkService ipVersion) (lib.filterAttrs (_: inst: inst.enable) instances);

  allServices = (mkServices "v4" cfg.instances.v4) ++ (mkServices "v6" cfg.instances.v6);
in
{
  options.services.myip = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Default enable value for all myip instances.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Default autostart value for all myip instances.";
    };

    package = lib.mkPackageOption pkgs "myip" { };

    instances.v4 = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = "IPv4 myip instances.";
    };

    instances.v6 = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = "IPv6 myip instances.";
    };
  };

  config = lib.mkIf (allServices != [ ]) {
    systemd.services = lib.listToAttrs allServices;
  };
}
