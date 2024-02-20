{
  nixConfig = rec {
    experimental-features = [ "nix-command" "flakes" ];

    substituters = [
      # Replace official cache with a mirror located in China
      #
      # Feel free to remove this line if you are not in China
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store" # 中科大
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" #清华
      "https://mirrors.bfsu.edu.cn/nix-channels/store" # 北外
      "https://mirror.sjtu.edu.cn/nix-channels/store" #交大
      #"https://cache.nixos.org"
    ];
    trusted-substituters = substituters;
    trusted-users = [
      "coder"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in
      {
        defaultPackage = pkgs.buildGoModule {
          pname = "go-webdav";
          version = "0.1.0";
          src = ./.;
          meta = with lib; {
            description = "Simple Go WebDAV server.";
            homepage = "https://github.com/senseab/webdav";
            license = licenses.mit;
            maintainers = with maintainers; [ ];
          };
          vendorHash = "sha256-az+EasmKitFPWD5JfKaSKZGok/n/dPmIv90RiL750KY=";
        };

        devShell = with pkgs; mkShell {
          buildInputs = [
            go
            nixpkgs-fmt
          ];
        };

        nixosModule = { config, pkgs, lib, ... }: with lib;
          let
            cfg = config.services.go-webdav;

            readOnly = mkOption {
              type = types.bool;
              default = true;
            };

            rules = mkOption {
              types = types.listOf types.submodule {
                options = {
                  regex = mkOption {
                    type = types.bool;
                    default = false;
                  };

                  allow = mkOption {
                    type = types.bool;
                    default = true;
                  };

                  path = mkOption {
                    type = types.str;
                  };

                  readOnly = readOnly;
                };
              };
              default = [ ];
            };
          in
          {
            options.services.go-webdav = {
              enable = mkEnableOption "go-webdav service";

              dir = mkOption {
                type = types.str;
                default = "/srv/webdav";
              };

              address = mkOption {
                type = types.str;
                default = "[::]";
                example = "0.0.0.0";
              };

              port = mkOption {
                type = types.port;
                default = 8080;
              };

              auth = mkOption {
                type = types.bool;
                default = true;
              };

              tls = mkOption {
                type = types.bool;
                default = false;
              };

              certFile = mkOption {
                type = types.nullOr types.str;
              };

              certKey = mkOption {
                type = types.nullOr types.str;
              };

              prefix = mkOption {
                type = types.str;
                default = "/";
                example = "/webdav";
              };

              debug = mkOption {
                type = types.bool;
                default = false;
              };

              cors = mkOption {
                type = types.submodule {
                  options = {
                    enabled = mkOption {
                      type = types.bool;
                      default = true;
                    };

                    credentials = mkOption {
                      type = types.bool;
                      default = true;
                    };

                    allowedHeaders = mkOption {
                      type = types.listOf types.str;
                      default = mkDefault [
                        "Depth"
                      ];
                    };

                    allowedHosts = mkOption {
                      type = types.listOf types.str;
                      default = mkDefault [
                        "*"
                      ];
                    };

                    allowedMethods = mkOption {
                      type = types.listOf types.str;
                      default = mkDefault [
                        "*"
                      ];
                    };

                    exposedHeaders = mkOption {
                      type = types.listOf types.str;
                      default = mkDefault [
                        "Content-Lenght"
                        "Content-Range"
                      ];
                    };
                  };
                };
              };

              defaultSettings = mkOption {
                type = types.submodule {
                  options = {
                    scope = mkOption {
                      types = types.str;
                      default = ".";
                    };

                    readOnly = readOnly;
                    rules = rules;
                  };
                };
              };

              users = mkOption {
                type = types.listOf types.submodule {
                  options = {
                    username = mkOption {
                      type = types.str;
                    };

                    password = mkOption {
                      type = types.str;
                    };

                    readOnly = readOnly;
                    rules = rules;
                  };
                };
              };
            };

            config =
              let
                davConfig = {
                  address = cfg.address;
                  port = cfg.port;
                  auth = cfg.auth;
                  tls = cfg.tls;
                  cert = if cfg?certFile then cfg.certFile else "";
                  key = if cfg?certKey then cfg.certKey else "";
                  prefix = cfg.prefix;
                  debug = cfg.debug;

                  scope = cfg.defaultSettings.scope;
                  modify = !cfg.defaultSettings.readOnly;
                  rules = builtins.map
                    (r: {
                      regex = r.regex;
                      allow = r.allow;
                      path = r.path;
                      modify = !r.readOnly;
                    })
                    cfg.defaultSettings.rules;

                  cors = {
                    enabled = cfg.cors.enabled;
                    credentials = cfg.cors.credentials;
                    allowed_headers = cfg.cors.allowedHeaders;
                    allowed_hosts = cfg.cors.allowedHosts;
                    allowed_methods = cfg.cors.allowedMethods;
                    exposed_headers = cfg.cors.exposedHeaders;
                  };

                  users = builtins.map
                    (u: {
                      username = u.username;
                      password = u.password;
                      modify = !u.readOnly;
                      rules = builtins.map
                        (r: {
                          regex = r.regex;
                          allow = r.allow;
                          path = r.path;
                          modify = !r.readOnly;
                        })
                        u.rules;
                    })
                    cfg.users;
                };
                configFile = pkgs.writeText "go-webdav.json" (builtins.toJSON davConfig);
              in
              mkIf cfg.enable {
                systemd.services.go-webdav = {
                  wantedBy = [ "multi-uesr.target" ];
                  serviceConfig.ExecStart = "${pkgs.go-webdav}/bin/webdav --config ${configFile}";
                  serviceConfig.Restart = "on-failure";
                  serviceConfig.Type = "simple";
                  serviceConfig.WorkingDirectory = cfg.dir;
                  after = [
                    "network.target"
                  ];
                  discription = "WebDAV Server";
                };
              };
          };
      });
}
