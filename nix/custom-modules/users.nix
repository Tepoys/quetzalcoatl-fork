
{ pkgs, lib, ... }:

let
  # Existing declaratively managed users to restrict.
  # Do not include bluey or root.
  restrictedUsers = [
  ];

  # Create rbash from the Nix-managed Bash package.
  restrictedBash = pkgs.runCommand "restricted-bash" {} ''
    mkdir -p "$out/bin"
    ln -s ${pkgs.bashInteractive}/bin/bash "$out/bin/rbash"
  '';

  # Only allow these commands through the restricted PATH.
  restrictedCommands = pkgs.runCommand "restricted-commands" {} ''
    mkdir -p "$out/bin"

    ln -s /opt/busybox/busybox $out/bin/ls
    ln -s /opt/busybox/busybox $out/bin/whoami
    ln -s /opt/busybox/busybox $out/bin/id
  '';

  # Login-shell wrapper. Set PATH before rbash starts.
  restrictedLogin = pkgs.writeShellScript "restricted-login" ''
    export PATH="${restrictedCommands}/bin"

    exec "${restrictedBash}/bin/rbash" \
      --noprofile --norc "$@"
  '';

in
{
  # Permit restrictedLogin as a login shell.
  environment.shells = [
    restrictedLogin
  ];

  # Apply the restricted shell to explicitly selected users.
  users.users =
    (lib.genAttrs restrictedUsers (_: {
      shell = restrictedLogin;
    }))
    // {
      bluey = {
        isNormalUser = true;
        description = "Blue Team Administrator";
        createHome = true;
        home = "/home/bluey";

        shell = pkgs.bashInteractive;

        extraGroups = [
          "wheel"
        ];

        hashedPasswordFile = "/run/secrets/bluey-password-hash";
      };
    };

  # Keep account management compatible with existing users.
  users.mutableUsers = true;
}

