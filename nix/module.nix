flake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.iggy-server;
  format = pkgs.formats.toml {};
  generatedConfigFile = format.generate "iggy-server.toml" cfg.settings;
  effectiveConfigFile =
    if cfg.configFile != null
    then cfg.configFile
    else generatedConfigFile;

  # Parse the effective config to derive firewall ports.
  # Uses the user-provided config file or the generated settings.
  parsedConfig =
    if cfg.configFile != null
    then builtins.fromTOML (builtins.readFile cfg.configFile)
    else cfg.settings;

  getPort = addr: lib.toInt (lib.last (lib.splitString ":" addr));
in {
  options.services.iggy-server = {
    enable = lib.mkEnableOption "Apache Iggy message streaming server";

    package = lib.mkOption {
      type = lib.types.package;
      default = flake.packages.${pkgs.system}.iggy-server;
      defaultText = lib.literalExpression "iggy.packages.\${pkgs.system}.iggy-server";
      description = "The iggy-server package to use.";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a custom iggy-server TOML configuration file.
        When set, this takes precedence over `settings`.
        See upstream `core/server/config.toml` for all available options.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/iggy";
      description = "Directory for iggy-server data storage.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "iggy";
      description = "User account under which iggy-server runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "iggy";
      description = "Group under which iggy-server runs.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open firewall ports for enabled iggy-server transports, derived from the effective configuration.";
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      description = ''
        Freeform configuration for iggy-server as a Nix attribute set.
        Converted to TOML and passed via IGGY_CONFIG_PATH.
        Ignored when `configFile` is set.
        See upstream `core/server/config.toml` for all available options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Wire dataDir into settings when using the generated config.
    services.iggy-server.settings.system.path =
      lib.mkIf (cfg.configFile == null) (lib.mkDefault cfg.dataDir);

    users.users = lib.mkIf (cfg.user == "iggy") {
      iggy = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        description = "Iggy server user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "iggy") {
      iggy = {};
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.iggy-server = {
      description = "Apache Iggy Message Streaming Server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      environment.IGGY_CONFIG_PATH = toString effectiveConfigFile;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/iggy-server";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "5s";
        LimitNOFILE = 65536;
        LimitMEMLOCK = "infinity";

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ReadWritePaths = [cfg.dataDir];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      # Basically, if the final config has `<proto>.enabled` set, then open the pots with the associated address (or default).
      allowedTCPPorts =
        lib.optional (parsedConfig.http.enabled or true)
          (getPort (parsedConfig.http.address or "127.0.0.1:3000"))
        ++ lib.optional (parsedConfig.tcp.enabled or true)
          (getPort (parsedConfig.tcp.address or "127.0.0.1:8090"))
        ++ lib.optional (parsedConfig.websocket.enabled or true)
          (getPort (parsedConfig.websocket.address or "127.0.0.1:8092"));
      allowedUDPPorts =
        lib.optional (parsedConfig.quic.enabled or true)
          (getPort (parsedConfig.quic.address or "127.0.0.1:8080"));
    };
  };
}
