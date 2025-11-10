{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.omnitools;
in
{
  options.services.omnitools = {
    enable = mkEnableOption "OmniTools";

    location = mkOption {
      type = types.str;
      description = "Path where omnitools data will be stored";
    };

    subdomain = mkOption {
      type = types.str;
      default = "tools";
      description = "Subdomain for accessing OmniTools";
    };

    internalPort = mkOption {
      type = types.int;
      default = 8080;
      description = "Internal port to bind OmniTools on localhost";
    };
  };

  config = cfg.enable {
      # Enable Docker
      virtualisation.docker.enable = true;

      # Create systemd slice for the module
      systemd.slices."omnitools" = {
        description = "OmniTools Slice";
      };

      # Create the systemd service to run the Docker container
      systemd.services.omnitools = {
        description = "OmniTools Container";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          Slice = "omnitools";
          Restart = "always";
          RestartSec = 5;
          User = "root";

          # Pull and run the Docker image with volume mount for data persistence
          ExecStartPre = "${pkgs.docker}/bin/docker pull iib0011/omni-tools:latest";
          ExecStart = "${pkgs.docker}/bin/docker run --rm --name omni-tools -v ${cfg.location}:/app/data -p 127.0.0.1:${toString cfg.internalPort}:80 iib0011/omni-tools:latest";
          ExecStop = "${pkgs.docker}/bin/docker stop omni-tools";
        };
      };

      # Reverse proxy configuration for web browser access
      services.nginx.virtualHosts."${cfg.subdomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.internalPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
    }
}
