flake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.iggy-server;
  format = pkgs.formats.toml {};
  configFile = format.generate "iggy-server.toml" cfg.settings;
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

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/iggy";
      description = "Directory for iggy-server data storage. Sets `system.path` in the server configuration.";
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
      description = "Whether to open firewall ports for enabled iggy-server transports.";
    };

    settings = lib.mkOption {
      default = {};
      description = ''
        Configuration for iggy-server as a Nix attribute set.
        Converted to TOML and passed via IGGY_CONFIG_PATH.
        See upstream config.toml for all available options.
        Any setting not explicitly typed can be set as a freeform attribute.
      '';
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          http = lib.mkOption {
            default = {};
            description = "HTTP server configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable the HTTP server.";
                };
                address = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1:3000";
                  description = "HTTP server listen address.";
                };
                max_request_size = lib.mkOption {
                  type = lib.types.str;
                  default = "2 MB";
                  description = "Maximum HTTP request body size.";
                };
                web_ui = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to enable the embedded Web UI dashboard.";
                };
              };
            };
          };

          tcp = lib.mkOption {
            default = {};
            description = "TCP server configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable the TCP server.";
                };
                address = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1:8090";
                  description = "TCP server listen address.";
                };
                ipv6 = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to use IPv6 instead of IPv4.";
                };
              };
            };
          };

          quic = lib.mkOption {
            default = {};
            description = "QUIC server configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable the QUIC server.";
                };
                address = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1:8080";
                  description = "QUIC server listen address.";
                };
                max_concurrent_bidi_streams = lib.mkOption {
                  type = lib.types.int;
                  default = 10000;
                  description = "Maximum number of simultaneous bidirectional streams.";
                };
                keep_alive_interval = lib.mkOption {
                  type = lib.types.str;
                  default = "5 s";
                  description = "Interval for sending keep-alive messages.";
                };
                max_idle_timeout = lib.mkOption {
                  type = lib.types.str;
                  default = "10 s";
                  description = "Maximum idle time before connection is closed.";
                };
              };
            };
          };

          websocket = lib.mkOption {
            default = {};
            description = "WebSocket server configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable the WebSocket server.";
                };
                address = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1:8092";
                  description = "WebSocket server listen address.";
                };
              };
            };
          };

          system = lib.mkOption {
            default = {};
            description = "System configuration (storage, logging, encryption, etc.).";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                logging = lib.mkOption {
                  default = {};
                  description = "Logging configuration.";
                  type = lib.types.submodule {
                    freeformType = format.type;
                    options = {
                      level = lib.mkOption {
                        type = lib.types.str;
                        default = "info";
                        description = "Log level (trace, debug, info, warn, error, off).";
                      };
                      file_enabled = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                        description = "Whether to write logs to files.";
                      };
                      max_file_size = lib.mkOption {
                        type = lib.types.str;
                        default = "500 MB";
                        description = "Maximum size of a single log file before rotation.";
                      };
                      max_total_size = lib.mkOption {
                        type = lib.types.str;
                        default = "4 GB";
                        description = "Maximum total size of all log files.";
                      };
                      retention = lib.mkOption {
                        type = lib.types.str;
                        default = "7 days";
                        description = "Time to retain log files before deletion.";
                      };
                    };
                  };
                };

                encryption = lib.mkOption {
                  default = {};
                  description = "Server-side encryption configuration (AES-256-GCM).";
                  type = lib.types.submodule {
                    freeformType = format.type;
                    options = {
                      enabled = lib.mkOption {
                        type = lib.types.bool;
                        default = false;
                        description = "Whether to enable server-side encryption.";
                      };
                    };
                  };
                };

                memory_pool = lib.mkOption {
                  default = {};
                  description = "Memory pool configuration.";
                  type = lib.types.submodule {
                    freeformType = format.type;
                    options = {
                      enabled = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                        description = "Whether to enable the memory pool.";
                      };
                      size = lib.mkOption {
                        type = lib.types.str;
                        default = "4 GiB";
                        description = "Memory pool size (multiple of 4096 bytes, minimum 512 MiB).";
                      };
                    };
                  };
                };

                segment = lib.mkOption {
                  default = {};
                  description = "Segment configuration.";
                  type = lib.types.submodule {
                    freeformType = format.type;
                    options = {
                      size = lib.mkOption {
                        type = lib.types.str;
                        default = "1 GiB";
                        description = "Segment soft size limit (max 1 GiB, multiple of 512 B).";
                      };
                    };
                  };
                };

                sharding = lib.mkOption {
                  default = {};
                  description = "Sharding configuration.";
                  type = lib.types.submodule {
                    freeformType = format.type;
                    options = {
                      cpu_allocation = lib.mkOption {
                        type = lib.types.str;
                        default = "numa:auto";
                        description = ''
                          CPU allocation strategy. Options:
                          - "all": use all cores
                          - numeric (e.g. "4"): use N shards
                          - range (e.g. "5..8"): use cores 5-7
                          - "numa:auto": auto-detect NUMA topology
                          - "numa:nodes=0,1;cores=4;no_ht=true": explicit NUMA config
                        '';
                      };
                    };
                  };
                };
              };
            };
          };

          message_saver = lib.mkOption {
            default = {};
            description = "Background message saver configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enable the background message saver.";
                };
                enforce_fsync = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to enforce fsync for durability.";
                };
                interval = lib.mkOption {
                  type = lib.types.str;
                  default = "30 s";
                  description = "Interval for running the message saver.";
                };
              };
            };
          };

          heartbeat = lib.mkOption {
            default = {};
            description = "Client heartbeat verification configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to enable client heartbeat verification.";
                };
                interval = lib.mkOption {
                  type = lib.types.str;
                  default = "5 s";
                  description = "Expected heartbeat interval.";
                };
              };
            };
          };

          cluster = lib.mkOption {
            default = {};
            description = "Cluster configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to enable cluster mode.";
                };
                name = lib.mkOption {
                  type = lib.types.str;
                  default = "iggy-cluster";
                  description = "Cluster name (must match across all nodes).";
                };
              };
            };
          };

          telemetry = lib.mkOption {
            default = {};
            description = "OpenTelemetry configuration.";
            type = lib.types.submodule {
              freeformType = format.type;
              options = {
                enabled = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether to enable OpenTelemetry.";
                };
                service_name = lib.mkOption {
                  type = lib.types.str;
                  default = "iggy";
                  description = "Service name for telemetry.";
                };
              };
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Wire dataDir into the server's system.path setting.
    services.iggy-server.settings.system.path = lib.mkDefault cfg.dataDir;

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

      environment.IGGY_CONFIG_PATH = toString configFile;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/iggy-server";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "5s";
        LimitNOFILE = 65536;

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
      allowedTCPPorts =
        lib.optional cfg.settings.http.enabled (getPort cfg.settings.http.address)
        ++ lib.optional cfg.settings.tcp.enabled (getPort cfg.settings.tcp.address)
        ++ lib.optional cfg.settings.websocket.enabled (getPort cfg.settings.websocket.address);
      allowedUDPPorts =
        lib.optional cfg.settings.quic.enabled (getPort cfg.settings.quic.address);
    };
  };
}
