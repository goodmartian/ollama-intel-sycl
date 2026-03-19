{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ollama-sycl;
in {
  options.services.ollama-sycl = {
    enable = lib.mkEnableOption "Ollama with Intel SYCL backend";

    package = lib.mkPackageOption pkgs "ollama-sycl" {};

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host to bind Ollama server.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for Ollama server.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ollama";
      description = "Home directory for Ollama data.";
    };

    models = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.home}/models";
      description = "Directory to store models.";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra environment variables for Ollama.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for Ollama.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.services.ollama-sycl = {
      description = "Ollama with SYCL backend for Intel Arc GPU";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment =
        {
          HOME = cfg.home;
          OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
          OLLAMA_MODELS = cfg.models;
          OLLAMA_NUM_GPU = "999";
          OLLAMA_FLASH_ATTENTION = "0";
          OLLAMA_DO_NOT_TRACK = "1";
        }
        // cfg.environmentVariables;
      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe cfg.package} serve";
        Restart = "on-failure";
        RestartSec = 5;
        StateDirectory = "ollama";
        DynamicUser = false;
        NoNewPrivileges = true;
        PrivateDevices = false;
        DeviceAllow = ["char-drm"];
        SupplementaryGroups = ["render" "video"];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
  };
}
