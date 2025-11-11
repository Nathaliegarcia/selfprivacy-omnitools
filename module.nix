{ config, lib, ... }:

let
  sp = config.selfprivacy;
  cfg = sp.modules.omnitools;
in
{
  options.selfprivacy.modules.omnitools = {
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable Omni-Tools";
    }) // {
      meta = {
        type = "enable";
      };
    };

    subdomain = (lib.mkOption {
      default = "tools";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
      description = "Subdomain";
    }) // {
      meta = {
        widget = "subdomain";
        type = "string";
        regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        weight = 0;
      };
    };

    internalPort = (lib.mkOption {
      default = 8080;
      type = lib.types.int;
      description = "Internal port for Omni-Tools";
    }) // {
      meta = {
        type = "int";
        weight = 1;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Docker
    virtualisation.docker.enable = true;

    # Create systemd slice for the module
    systemd.slices.omnitools = {
      description = "Omni-Tools Slice";
    };

    # Create the systemd service to run the Docker container
    systemd.services.omnitools = {
      description = "Omni-Tools Container";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Slice = "omnitools.slice";
        Restart = "always";
        RestartSec = 5;
        User = "root";

        # Pull and run the Docker image with volume mount for data persistence
        ExecStartPre = "${lib.getExe' (lib.getBin config.boot.kernelPackages.docker) "docker"} pull iib0011/omni-tools:latest";
        ExecStart = "${lib.getExe' (lib.getBin config.boot.kernelPackages.docker) "docker"} run --rm --name omnitools -v /var/lib/private/omnitools:/app/data -p 127.0.0.1:${toString cfg.internalPort}:80 iib0011/omni-tools:latest";
        ExecStop = "${lib.getExe' (lib.getBin config.boot.kernelPackages.docker) "docker"} stop omnitools";
      };

      unitConfig.RequiresMountsFor = lib.mkIf sp.useBinds "/var/lib/private/omnitools";
    };

    # Reverse proxy configuration for web browser access
    services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security $hsts_header;
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.internalPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout  60s;
          proxy_send_timeout  60s;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        '';
      };
    };
  };
}
