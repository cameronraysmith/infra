# Bootloader-backed KVM regulator for the fleet-shared
# `flake.modules.nixos.base` module.
#
# `vm-nixos-base` direct-boots kernel and initrd, so it must disable the one
# property `base` exists to guarantee for remote unlock: the clan-vars initrd
# SSH host key (`initrd-ssh`, `neededFor = "activation"`) is appended to the
# initrd by the bootloader install and served by the stage-1 sshd on 2222.
# This leaf installs systemd-boot into an EFI disk image, as the fleet does,
# holds stage 1 open with the upstream initrd backdoor while a second node
# key-scans the initrd sshd, then switches root and inspects the on-disk
# initrd, the activation var, and the services/users phases of clan's
# age-backed secret delivery.
#
# Production uploads activation-phase vars with `clan machines update`;
# clanTest only decrypts the services/users phases. The activation script
# below stands in for that upload, and `nixos-enter` runs activation inside
# the image chroot before `switch-to-configuration boot`, so the var exists
# when `append-initrd-secrets` copies it.
{
  config,
  inputs,
  lib,
  ...
}:
let
  nixosLib = import (inputs.nixpkgs + "/nixos/lib") { };
  base = config.flake.modules.nixos.base;
  ageSourcePath = import (
    inputs.clan-core + "/nixosModules/clanCore/vars/secret/age-source-path.nix"
  );
  initrdSshPort = 2222;

  stageActivationVars =
    { config, pkgs, ... }:
    let
      clanDir = config.clan.core.settings.directory;
      keyFile = "${config.clan.core.vars.age.secretLocation}/key.txt";
      activationVars = lib.concatMap (
        gen: lib.filter (f: f.secret && f.deploy && f.neededFor == "activation") (lib.attrValues gen.files)
      ) (lib.attrValues config.clan.core.vars.generators);
    in
    {
      system.activationScripts.stageActivationVars = {
        deps = [ "testAgeKeySetup" ];
        text = lib.concatMapStrings (f: ''
          mkdir -p "$(dirname "${f.path}")"
          ${lib.getExe' pkgs.age "age"} --decrypt -i "${keyFile}" -o "${f.path}" \
            "${ageSourcePath clanDir f.rel_dir f.name}"
          chmod ${f.mode} "${f.path}"
          chown ${f.owner}:${f.group} "${f.path}"
        '') activationVars;
      };
    };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        vm-nixos-base-bootloader = nixosLib.runTest {
          imports = [ inputs.clan-core.modules.nixosTest.clanTest ];
          hostPkgs = pkgs;
          name = "vm-nixos-base-bootloader";
          extraPythonPackages = lib.mkForce (_: [ ]);
          clan = {
            directory = pkgs.emptyDirectory;
            test.useContainers = false;
            inventory.machines = {
              probe = { };
              client = { };
            };
            machines.probe =
              { config, ... }:
              {
                imports = [
                  base
                  stageActivationVars
                ];
                system.stateVersion = config.system.nixos.release;
                boot.loader = {
                  systemd-boot.enable = true;
                  efi.canTouchEfiVariables = true;
                };
                environment.systemPackages = [ pkgs.zstd ];
                clan.core.vars.generators.age-probe = {
                  files.service-secret = {
                    owner = "crs58";
                    group = "users";
                    mode = "0440";
                  };
                  files.user-secret.neededFor = "users";
                  runtimeInputs = [ pkgs.coreutils ];
                  script = ''
                    printf age-probe-service > "$out/service-secret"
                    printf age-probe-user > "$out/user-secret"
                  '';
                };
              };
            machines.client =
              { config, ... }:
              {
                system.stateVersion = config.system.nixos.release;
              };
          };
          nodes.probe = {
            virtualisation = {
              useBootLoader = true;
              useEFIBoot = true;
            };
            testing.initrdBackdoor = true;
          };
          testScript =
            { nodes, ... }:
            let
              vars = nodes.probe.config.clan.core.vars.generators;
              initrdKey = vars.initrd-ssh.files.id_ed25519;
              initrdPub = vars.initrd-ssh.files."id_ed25519.pub";
              serviceSecret = vars.age-probe.files.service-secret;
              userSecret = vars.age-probe.files.user-secret;
            in
            ''
              import time
              from pathlib import Path

              start_all()

              # 1. stage 1 is systemd-initrd and its sshd serves the generated host key on ${toString initrdSshPort}
              probe.wait_for_unit("initrd.target")
              probe.succeed("test -f /etc/initrd-release")
              probe.wait_for_unit("sshd.service")
              probe.succeed("test -f ${initrdKey.path}")

              client.wait_for_unit("multi-user.target")
              deadline = time.monotonic() + 90
              scanned = ""
              while "ssh-ed25519" not in scanned and time.monotonic() < deadline:
                  scanned = client.succeed(
                      "ssh-keyscan -T 5 -p ${toString initrdSshPort} -t ed25519 probe 2>/dev/null || true"
                  )
                  time.sleep(1)
              sshd_config = probe.succeed("cat /etc/ssh/sshd_config")
              assert "ssh-ed25519" in scanned, (
                  f"no ed25519 host key served by the initrd sshd on probe:${toString initrdSshPort}\n"
                  f"stage-1 sshd_config:\n{sshd_config}"
              )
              served = next(l for l in scanned.splitlines() if "ssh-ed25519" in l).split()[1:3]
              expected = Path("${initrdPub.flakePath}").read_text().split()[0:2]
              assert served == expected, (
                  f"initrd sshd serves {served}, generator initrd-ssh published {expected}"
              )

              # 2. stage 2: the activation var persists with clan's promised permissions
              #    and the bootloader-installed initrd carries the appended secret
              probe.switch_root()
              probe.wait_for_unit("multi-user.target")

              key_stat = probe.succeed("stat -c '%U:%G %a' ${initrdKey.path}").strip()
              assert key_stat == "root:root 400", f"${initrdKey.path} is {key_stat}, expected root:root 400"
              key_mount = probe.succeed("findmnt -n -o TARGET -T ${initrdKey.path}").strip()
              assert key_mount == "/", (
                  f"${initrdKey.path} resides on {key_mount}, expected the persistent root filesystem "
                  "(activation vars are uploaded before activation, not decrypted into a runtime ramfs)"
              )

              entry = probe.succeed(
                  "grep -l \"$(readlink -f /run/current-system)/init\" /boot/loader/entries/*.conf"
              ).strip()
              initrd = probe.succeed(f"awk '/^initrd /{{print $2}}' {entry}").strip()
              probe.succeed(f"zstd -dc /boot{initrd} > /tmp/initrd.cpio")
              _, appended = probe.execute("grep -a -c -F '.initrd-secrets${initrdKey.path}' /tmp/initrd.cpio")
              assert int(appended) > 0, (
                  f"bootloader entry {entry} initrd {initrd} does not contain .initrd-secrets${initrdKey.path}"
              )

              # 3. age-backed vars are decrypted at their promised phase with the promised permissions
              for path, phase_dir, content, perms in [
                  ("${serviceSecret.path}", "/run/secrets", "age-probe-service", "crs58:users 440"),
                  ("${userSecret.path}", "/run/user-secrets", "age-probe-user", "root:root 400"),
              ]:
                  assert path.startswith(phase_dir + "/"), f"{path} is not under {phase_dir}"
                  fstype = probe.succeed(f"findmnt -n -o FSTYPE {phase_dir}").strip()
                  assert fstype == "ramfs", f"{phase_dir} is {fstype!r}, expected ramfs"
                  got = probe.succeed(f"cat {path}")
                  assert got == content, f"{path} decrypted to {got!r}, expected {content!r}"
                  st = probe.succeed(f"stat -c '%U:%G %a' {path}").strip()
                  assert st == perms, f"{path} is {st}, expected {perms}"
            '';
        };
      };
    };
}
