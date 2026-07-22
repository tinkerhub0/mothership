# Operator ergonomics on the host shell. Not member tooling, not deck services.
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
