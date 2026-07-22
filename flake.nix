{
  description = "tinkerhub mothership — declarative host; git is the identity provider";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
  };

  outputs =
    {
      self,
      nixpkgs,
      srvos,
      disko,
      nixos-facter-modules,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      nixosConfigurations.mothership = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          srvos.nixosModules.server
          disko.nixosModules.disko
          nixos-facter-modules.nixosModules.facter
          ./hosts/mothership
        ];
      };

      # Local operator shell — works on this Mac and on the server.
      #   nix develop
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          isLinux = pkgs.stdenv.isLinux;
        in
        {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                git
                jq
                nixfmt
              ]
              ++ lib.optionals isLinux [
                headscale
                tailscale
              ];

            shellHook = ''
              cat <<'EOF'
              mothership dev shell
              ────────────────────
              Eval host name:   nix eval .#nixosConfigurations.mothership.config.networking.hostName
              Eval mesh IP:     nix eval .#nixosConfigurations.mothership.config.mothership.mesh.mothershipIPv4
              Eval headscale:   nix eval .#nixosConfigurations.mothership.config.services.headscale.enable
              Format:           nixfmt .
              Checks:           nix flake check
              Hardware (server): ./scripts/capture-hardware.sh

              Full NixOS build needs x86_64-linux (the box or a remote builder).
              EOF
            '';
          };
        }
      );

      # Lightweight checks that don't need a full system build.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          host = self.nixosConfigurations.mothership.config;
        in
        {
          hostname = pkgs.runCommand "check-hostname" { } ''
            test "${host.networking.hostName}" = "mothership"
            touch $out
          '';
          mesh-ip = pkgs.runCommand "check-mesh-ip" { } ''
            test "${host.mothership.mesh.mothershipIPv4}" = "100.64.0.1"
            touch $out
          '';
          headscale-enabled = pkgs.runCommand "check-headscale" { } ''
            test "${if host.services.headscale.enable then "true" else "false"}" = "true"
            touch $out
          '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
