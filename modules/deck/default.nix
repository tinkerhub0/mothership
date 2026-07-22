# Deck systems — shared hub services that run on the mothership.
#
# Not member VMs (user-vms/). Not host identity (hosts/mothership/).
# Outside the git-as-IdP chain: web logins stay local until Dex bridges GitHub.
#
# One file per service. Enable only through mothership.deck.*.enable.
{
  imports = [
    ./mattermost.nix
    # ./vaultwarden.nix
  ];
}
