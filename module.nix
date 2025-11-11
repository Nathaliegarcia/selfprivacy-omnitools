{ config, lib, pkgs, ... }:

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
      default = "8080";
      type = lib.types.strMatching "[0-9]{1,5}";
      description = "Internal port for Omni-Tools";
    }) // {
      meta = {
        type = "string";
        regex = "[0-9]{1,5}";
      };
    };
  };


  config = lib.mkIf cfg.enable {
    # Use Podman as backend for OCI containers
    virtualisation.oci-containers = {
      backend = "podman";
      containers.omnitools = {
        image = "iib0011/omni-tools:latest";
        # published ports
        ports = [ "127.0.0.1:${toString cfg.internalPort}:80" ];
        # volumes
        volumes = [ "/var/lib/private/omnitools:/app/data" ];
        # ensure a stable name
        extraOptions = [ "--name=omnitools" ];
        # (optional) always pull latest on start
        pullPolicy = "always";
      };
    };

    # Data dir with proper ownership/permissions
    systemd.services."podman-omnitools".serviceConfig = {
      StateDirectory = "omnitools";
      StateDirectoryMode = "0750";
    };

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
