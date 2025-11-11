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
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;
    virtualisation.podman.rootless.enable = true;
    environment.systemPackages = [ pkgs.slirp4netns pkgs.fuse-overlayfs ];

    users.groups.podman = {};
    users.groups.onmitools = {};
    users.users.onmitools = {
      isSystemUser = true;
      description = "Omni-Tools rootless runner";
      home = "/var/lib/onmitools";
      createHome = true;
      shell = pkgs.nologin;
      group = "onmitools";
      linger = true;
      extraGroups = [ "podman" ];
      subUidRanges = [{ start = 100000; count = 65536; }];
      subGidRanges = [{ start = 100000; count = 65536; }];
    };

    #services.logind.lingerUsers = [ "onmitools" ];
    systemd.user.services.omnitools = {
      description = "Omni-Tools (rootless via Podman)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --name omnitools \
            --pull=newer --rm \
            -p 127.0.0.1:8989:80 \
            docker.io/iib0011/omni-tools:latest
        '';
        ExecStop = "${pkgs.podman}/bin/podman stop -t 10 omnitools";
        Restart = "always";
        RestartSec = 5;
      };
    };
    
    
    # Bootstrap (active l’unité pour l’utilisateur au boot)
    systemd.services.omnitools-user-bootstrap = {
      description = "Enable & start omnitools user service for onmitools";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "systemd-user-sessions.service" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user daemon-reload
        ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user enable --now omnitools
      '';
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
        proxyPass = "http://127.0.0.1:8989";
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
