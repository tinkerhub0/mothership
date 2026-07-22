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
    };
}
