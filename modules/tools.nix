# tools — operator surface on the host shell.
# not member tooling. not deck services. htop is not a product.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    dig
    git
    htop
    jq
    pciutils
    ripgrep
    rsync
    tmux
    tree
    usbutils
    vim
    wget
  ];

  programs.zsh.enable = true;
}
