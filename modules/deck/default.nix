# deck — shared hub services on the mothership.
#
# not member VMs (user-vms/). not host identity (hosts/mothership/).
# outside the git-as-IdP chain: web logins stay local until Dex → GitHub.
#
# one file per service. enable only via mothership.deck.*.enable.
# if you know you know.
{
  imports = [
    ./mattermost.nix
    # ./vaultwarden.nix
  ];
}
