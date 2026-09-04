{ config, ... }:
{
  flake.users.ubuntu = {
    meta = {
      username = "ubuntu";
      fullname = "Cameron Smith";
      email = "cameron.ray.smith@gmail.com";
      githubUser = "cameronraysmith";
      sopsAgeKeyId = null;
      sshKeys = [ ];
    };
    aggregates = with config.flake.modules.homeManager; [
      base-sops
      terminal
    ];
  };
}
