{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkPackageOption
    mkOption
    mkIf
    mkMerge
    types
    ;

  cfg = config.services.lemonldap-ng;

  ini = pkgs.formats.ini { };
  json = pkgs.formats.json { };

  lemonldapIniConfiguration = ini.generate "lemonldap-ng.ini" cfg.settings;
  lemonldapSharedConfiguration = json.generate "lemonldap-ng.json" cfg.sharedConfiguration;

  mkService = description: ExecStart: {
    inherit description;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      mkdir -p $STATE_DIRECTORY/conf

      ln -sf ${lemonldapSharedConfiguration} $STATE_DIRECTORY/conf/lmConf-1.json
    '';

    environment = {
      LLNG_DEFAULTCONFFILE = lemonldapIniConfiguration;
    };

    serviceConfig = {
      inherit ExecStart;
      RuntimeDirectory = "lemonldap-ng";
      StateDirectory = "lemonldap-ng";
      WorkingDirectory = "/var/lib/lemonldap-ng";

      User = "lemonldap-ng";
      DynamicUser = true;
      UMask = "0077";
    };
  };
in
{
  options.services.lemonldap-ng = {
    manager = {
      enable = mkEnableOption "LemonLDAP::NG Manager";

      package = mkPackageOption pkgs "lemonldap-ng-manager" { };

      domain = mkOption {
        type = types.str;
        description = ''
          Domain name of the manager instance.
        '';
      };

      binds = mkOption {
        type = types.listOf types.str;
        default = [ "/var/lib/lemonldap-ng/manager.sock" ];
        description = ''
          Listens on one or more addresses, whether "HOST:PORT", ":PORT", or
          "PATH" (without colons). You may use this option multiple times to
          listen on multiple addresses, but the server will decide whether it
          supports multiple interfaces.
        '';
      };
    };

    portal = {
      enable = mkEnableOption "LemonLDAP::NG Portal";

      package = mkPackageOption pkgs "lemonldap-ng-portal" { };

      domain = mkOption {
        type = types.str;
        description = ''
          Domain name of the portal instance.
        '';
      };

      binds = mkOption {
        type = types.listOf types.str;
        default = [ "/var/lib/lemonldap-ng/portal.sock" ];
        description = ''
          Listens on one or more addresses, whether "HOST:PORT", ":PORT", or
          "PATH" (without colons). You may use this option multiple times to
          listen on multiple addresses, but the server will decide whether it
          supports multiple interfaces.
        '';
      };
    };

    enableNginx = mkEnableOption "enable and configure Nginx for reverse proxying" // {
      default = true;
    };

    extraPlackUpArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Extra options to pass to plackup.
      '';
    };

    settings = mkOption {
      type = types.submodule {
        freeformType = ini.type;

        options = {
          configuration = {
            dirName = mkOption {
              type = types.str;
              default = "/var/lib/lemonldap-ng/conf";
              readOnly = true;
              description = "Path to the configuration of LemonLDAP::NG";
            };
          };
          portal = {
            staticPrefix = mkOption {
              type = types.str;
              default = "static";
              description = "Path to the static files of LemonLDAP::NG Portal";
            };
            templateDir = mkOption {
              type = types.str;
              default = "${cfg.portal.package}/share/templates";
              defaultText = lib.literalExpression "\${cfg.portal.package}/share/templates";
              description = "Path to the template files of LemonLDAP::NG Portal";
            };
          };
          manager = {
            protection = mkOption {
              type = types.str;
              default = "manager";
              description = "Manager protection of LemonLDAP::NG";
            };
            staticPrefix = mkOption {
              type = types.str;
              default = "static";
              description = "Path to the static files of LemonLDAP::NG Manager";
            };
            docPrefix = mkOption {
              type = types.str;
              default = "doc";
              description = "Path to the documentation files of LemonLDAP::NG Manager";
            };
            templateDir = mkOption {
              type = types.str;
              default = "${cfg.manager.package}/share/templates";
              defaultText = lib.literalExpression "\${cfg.manager.package}/share/templates";
              description = "Path to the template files of LemonLDAP::NG Manager";
            };
          };
        };
      };

      default = { };
      description = ''
        Configuration options of LemonLDAP::NG.

        See [the wiki](https://lemonldap-ng.org/documentation/latest/configlocation.html) for more information.
      '';
    };

    sharedConfiguration = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Shared configuration of LemonLDAP::NG.

        See [the wiki](https://lemonldap-ng.org/documentation/latest/configlocation.html) for more information.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.manager.enable {
      systemd.services.lemonldap-ng-manager = mkService "LemonLDAP::NG Manager" (
        utils.escapeSystemdExecArgs (
          [ (getExe cfg.manager.package) ]
          ++ (map (bind: "--listen=${bind}") cfg.manager.binds)
          ++ cfg.extraPlackUpArgs
        )
      );
    })
    (mkIf cfg.portal.enable {
      systemd.services.lemonldap-ng-portal = mkService "LemonLDAP::NG Portal" (
        utils.escapeSystemdExecArgs (
          [ (getExe cfg.portal.package) ]
          ++ (map (bind: "--listen=${bind}") cfg.portal.binds)
          ++ cfg.extraPlackUpArgs
        )
      );
    })
    (mkIf (cfg.manager.enable && cfg.enableNginx) {
      services.lemonldap-ng.manager.binds = [ "/run/lemonldap-ng/manager.sock" ];
      systemd.services.lemonldap-ng-manager.postStart = ''
        while [[ ! -e /run/lemonldap-ng/manager.sock ]]; do
          sleep 1
        done
        chmod 777 /run/lemonldap-ng/manager.sock
      '';
      services.nginx = {
        enable = true;
        virtualHosts.${cfg.manager.domain} = {
          locations."/" = {
            proxyPass = "http://unix:/run/lemonldap-ng/manager.sock";
            recommendedProxySettings = true;
          };

          locations."/doc/" = {
            alias = "${cfg.manager.package}/share/doc/";
            index = "index.html start.html";
          };

          locations."/static/" = {
            alias = "${cfg.manager.package}/share/static/";
          };
        };
      };
    })
    (mkIf (cfg.portal.enable && cfg.enableNginx) {
      services.lemonldap-ng.portal.binds = [ "/run/lemonldap-ng/portal.sock" ];
      systemd.services.lemonldap-ng-portal.postStart = ''
        while [[ ! -e /run/lemonldap-ng/portal.sock ]]; do
          sleep 1
        done
        chmod 777 /run/lemonldap-ng/portal.sock
      '';
      services.nginx = {
        enable = true;
        virtualHosts.${cfg.portal.domain} = {
          locations."/" = {
            proxyPass = "http://unix:/run/lemonldap-ng/portal.sock";
            recommendedProxySettings = true;
          };

          locations."/static/" = {
            alias = "${cfg.portal.package}/share/static/";
          };
        };
      };
    })
  ];

  meta = {
    buildDocsInSandbox = false;
    maintainers = [ lib.maintainers.soyouzpanda ];
  };
}
