{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.selfprivacy.modules.omni-tools;
in
{
  options.selfprivacy.modules.omni-tools = {
    enable = mkEnableOption "Omni-Tools";

    subdomain = mkOption {
      type = types.str;
      default = "tools";
      description = "Subdomain for accessing Omni-Tools";
    };

    internalPort = mkOption {
      type = types.int;
      default = 8080;
      description = "Internal port to bind Omni-Tools on localhost";
    };

    containerPort = mkOption {
      type = types.int;
      default = 80;
      description = "Port exposed by the container";
    };
  };

  config = mkIf cfg.enable {
    # Enable Docker
    virtualisation.docker.enable = true;

    # Create systemd slice for the module
    systemd.slices."omni_tools" = {
      description = "Omni-Tools Slice";
    };

    # Create the systemd service to run the Docker container
    systemd.services."omni-tools" = {
      description = "Omni-Tools Container";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Slice = "omni_tools";
        Restart = "always";
        RestartSec = 5;

        # Pull and run the Docker image
        ExecStartPre = "${pkgs.docker}/bin/docker pull iib0011/omni-tools:latest";
        ExecStart = "${pkgs.docker}/bin/docker run --rm --name omni-tools -p 127.0.0.1:${toString cfg.internalPort}:${toString cfg.containerPort} iib0011/omni-tools:latest";
        ExecStop = "${pkgs.docker}/bin/docker stop omni-tools";
      };
    };

    # Reverse proxy configuration for web browser access
    services.nginx.virtualHosts."${cfg.subdomain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.internalPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
