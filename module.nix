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
    environment.systemPackages = [ pkgs.slirp4netns pkgs.fuse-overlayfs ];

    users.groups.podman = {};
    users.groups.onmitools = {};
    users.users.onmitools = {
      isSystemUser = true;
      description = "Omni-Tools rootless runner";
      home = "/var/lib/onmitools";
      createHome = true;
      #shell = pkgs.nologin;
      group = "onmitools";
      linger = true;
      extraGroups = [ "podman" ];
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
    
    
    systemd.services.omnitools-user-bootstrap = {
      description = "Enable & start omnitools user service for onmitools";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "systemd-user-sessions.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        uid="$(id -u onmitools)"
        export XDG_RUNTIME_DIR="/run/user/$uid"
    
        # Assure le runtime dir (si le user manager n’a pas encore démarré)
        if [ ! -d "$XDG_RUNTIME_DIR" ]; then
          mkdir -p "$XDG_RUNTIME_DIR"
          chown onmitools:onmitools "$XDG_RUNTIME_DIR"
          chmod 700 "$XDG_RUNTIME_DIR"
        fi
    
        # Recharge les unités user
        ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user daemon-reload || true
    
        # Active l'unité si pas déjà fait
        if ! ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user is-enabled omnitools >/dev/null 2>&1; then
          ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user enable omnitools || true
        fi
    
        # Démarre l'unité si pas active
        if ! ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user is-active omnitools >/dev/null 2>&1; then
          ${pkgs.util-linux}/bin/runuser -u onmitools -- systemctl --user start omnitools || true
        fi
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
