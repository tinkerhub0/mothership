{
  description = "mothership — git is the IdP; Nix is the compiler; if you know you know";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    srvos.url = "github:nix-community/srvos";
    srvos.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      srvos,
      disko,
      nixos-facter-modules,
      microvm,
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

      # house firewall — opnsense, not nixos. data in hosts/tharavadmathil,
      # pushed by scripts/opnsense-apply.
      opnsense = import ./lib/opnsense.nix { inherit (nixpkgs) lib; };
      tharavadmathil = import ./hosts/tharavadmathil;
    in
    {
      opnsense.tharavadmathil = {
        failures = opnsense.check tharavadmathil;
        resources = opnsense.resources tharavadmathil;
      };

      # public DNS as data — rendered for octoDNS by .github/workflows/dns.yml
      dns.zones."tharavad.xyz" = import ./dns/tharavad.xyz.nix;

      nixosConfigurations.mothership = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          srvos.nixosModules.server
          disko.nixosModules.disko
          nixos-facter-modules.nixosModules.facter
          microvm.nixosModules.host
          ./hosts/mothership
        ];
      };

      # public front door (VPS) — WG reverse + nginx → mothership Headscale
      # install: nixos-anywhere --flake .#edge root@178.105.120.5
      nixosConfigurations.edge = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          srvos.nixosModules.server
          disko.nixosModules.disko
          ./hosts/edge
        ];
      };

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
                sops # secrets/*.sops.* — decrypt with your own ssh key
              ]
              ++ lib.optionals isLinux [
                headscale
                tailscale
              ];

            shellHook = ''
              cat <<'EOF'
              mothership // operator shell
              read why-this-exist first.

              nix eval .#nixosConfigurations.mothership.config.networking.hostName
              nix eval .#nixosConfigurations.mothership.config.mothership.mesh.mothershipIPv4
              nix flake check
              scripts/signup --help

              full rebuild / microvms / headscale: linux box only
              EOF
            '';
          };
        }
      );

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
          # control plane is mothership; edge is proxy-only front door
          mothership-is-control = pkgs.runCommand "check-mothership-control" { } ''
            test "${if host.mothership.mesh.controlPlane then "true" else "false"}" = "true"
            touch $out
          '';
          microvms-enabled = pkgs.runCommand "check-microvms-enabled" { } ''
            test "${if host.mothership.microvms.enable then "true" else "false"}" = "true"
            touch $out
          '';
          edge-hostname = pkgs.runCommand "check-edge-hostname" { } ''
            test "${self.nixosConfigurations.edge.config.networking.hostName}" = "edge"
            touch $out
          '';
          edge-not-control = pkgs.runCommand "check-edge-not-control" { } ''
            test "${
              if self.nixosConfigurations.edge.config.mothership.mesh.controlPlane then "true" else "false"
            }" = "false"
            touch $out
          '';
          # firewall data is sane: dhcp inside the lan, monitors unique, refs resolve
          opnsense-tharavadmathil =
            let
              failures = self.opnsense.tharavadmathil.failures;
            in
            pkgs.runCommand "check-opnsense-tharavadmathil" { } (
              if failures == [ ] then
                "touch $out"
              else
                ''
                  printf '%s\n' ${pkgs.lib.escapeShellArgs failures} >&2
                  exit 1
                ''
            );
          # .sops.yaml recipients = the people in lib/adminKeys.nix, not machines.
          # admin added/removed → regenerate .sops.yaml + sops updatekeys.
          sops-recipients =
            let
              lib = pkgs.lib;
              machines = [
                "test-deploy"
                "mothership-edge-trigger"
              ];
              bare = k: lib.concatStringsSep " " (lib.take 2 (lib.splitString " " k));
              people = map bare (
                lib.filter (k: !lib.elem (lib.last (lib.splitString " " k)) machines) (import ./lib/adminKeys.nix)
              );
              sopsJson = lib.concatStringsSep "\n" (
                lib.filter (l: !lib.hasPrefix "#" l) (lib.splitString "\n" (builtins.readFile ./.sops.yaml))
              );
              recipients = (lib.head (builtins.fromJSON sopsJson).creation_rules).key_groups;
              ages = lib.concatMap (g: g.age) recipients;
            in
            pkgs.runCommand "check-sops-recipients" { } (
              if lib.sort lib.lessThan ages == lib.sort lib.lessThan people then
                "touch $out"
              else
                ''
                  echo ".sops.yaml recipients differ from the people in lib/adminKeys.nix" >&2
                  exit 1
                ''
            );
          edge-front-door = pkgs.runCommand "check-edge-front-door" { } ''
            test "${
              if self.nixosConfigurations.edge.config.mothership.mesh.frontDoor.enable then "true" else "false"
            }" = "true"
            touch $out
          '';
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
