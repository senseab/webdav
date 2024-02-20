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
    trusted-users =  [
      "coder"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, naersk }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in
      {
        defaultPackage = nixpkgs.buildGoModule rec{
          pname = "go-webdav";
          version = "0.1.0";
          src = ./.;
          meta = with lib; {
            description = "Simple Go WebDAV server.";
            homepage = "https://github.com/senseab/webdav";
            license = licenses.mit;
            maintainers = with maintainers; [];
          };
        };

        devShell = with pkgs; mkShell {
          buildInputs = [ 
            go
            nixpkgs-fmt
          ];
        };

        nixosModule =  {config, pkgs, lib, ...}: with lib; 
        let 
          cfg = config.services.go-webdav;
        in {
          options.services.go-webdav = {
            enable = mkEnableOption "go-webdav service";

            token = mkOption {
              type = types.str;
              example = "12345678:AAAAAAAAAAAAAAAAAAAAAAAAATOKEN";
              description = lib.mdDoc "Telegram bot token";
            };

            tgUri = mkOption {
              type = types.str;
              default = "https://api.telegram.org";
              example = "https://api.telegram.org";
              description = lib.mdDoc "Custom telegram api URI";
            };

            groupBanned = mkOption {
              type = types.listOf types.int;
              default = [];
              description = lib.mdDoc "GroupID blacklisted";
            };

            extraOptions = mkOption {
              type = types.str;
              description = lib.mdDoc "Extra option for bot.";
              default = "";
            };
          };

          config = let 
            args = "${cfg.extraOptions} ${if cfg?tgUri then "--api-uri ${escapeShellArg cfg.tgUri}" else ""} ${if cfg?groupBanned then concatStringsSep " " (lists.concatMap (group: ["-b ${group}"]) cfg.groupBanned) else ""}";
          in mkIf cfg.enable {
            systemd.services.go-webdav = {
              wantedBy = ["multi-uesr.target"];
              serviceconfig.ExecStart = "${pkgs.go-webdav}/bin/go-webdav ${args} ${escapeShellArg cfg.token}";
            };
          };
        };
      });
}
