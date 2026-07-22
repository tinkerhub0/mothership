# operators who can SSH the metal and rebuild.
# members live in user-vms/ — not here.
{ lib, ... }:
let
  adminKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPgJj9GEaxD16KIwrB0M9qxeaFy33iCuCo99Jm/dxbkO terminal-shop"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfCFpZCX3ZtQg6kLK9cbtMj7V+75/f4VJt+ztTDFkNL terminal-shop-dev"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjUI8xR62zvnfBKoJ/S5UcBE8/5A+jyqppDLWOgpikg nihal-tinkerhub"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMckfpjGyg3/Hx7Xu0racB/V/PlaY5TvmHQdkLC2y90G alvinliju44@gmail.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINE0TI9u5ePkeYdDfzQUbdRFNL/8s8C0rCoTjYsSIZF0 test-deploy"
  ];
in
{
  users.users.root.openssh.authorizedKeys.keys = adminKeys;

  users.users.mothership = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = adminKeys;
  };

  # agent / laptop rebuild without password prompts
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [
    "root"
    "@wheel"
    "mothership"
  ];
}
