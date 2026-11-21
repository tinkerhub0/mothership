{
  github = "fahshad-aju";
  tier = "large";
  enabled = true;

  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAi60Ob07UQOwnXxtnkpqeMp4IONiHsbQp8dmlKj2M7 fahshad@linux"
  ];

  publish = [
    { port = 3000; }
  ];
}
