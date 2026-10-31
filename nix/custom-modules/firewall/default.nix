
{ pkgs, lib, ... }:

let
  firewallGenerator = ./fire2term.sh;
  portSources = ./port-sources;
in
{
  # Disable the default NixOS firewall
  networking.firewall.enable = lib.mkForce false;
  networking.nftables.enable = lib.mkForce false;
  services.firewalld.enable = lib.mkForce false;

  systemd.services.firewalld.enable = lib.mkForce false;
  systemd.services.ufw.enable = lib.mkForce false;

  systemd.masked = [
    "firewalld.service"
    "ufw.service"
  ];

  # Provide iptables for manual inspection
  environment.systemPackages = [
    pkgs.iptables
  ];

  systemd.services.custom-firewall = {
    description = "Custom iptables firewall";

    wantedBy = [
      "network-pre.target"
      "multi-user.target"
    ];

    before = [
      "network-pre.target"
    ];

    unitConfig.DefaultDependencies = false;

    path = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iptables
      pkgs.procps
      pkgs.systemd
    ];

    environment.PORT_SOURCES = "${portSources}";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    restartIfChanged = true;

    script = ''
      # Generate firewall commands
      rules=$(mktemp)
      trap 'rm -f "$rules"' EXIT


      sh ${firewallGenerator} > "$rules"

      # Validate shell syntax before execution
      sh -n "$rules"

      # Execute generated commands
      sh "$rules"
    '';
  };
}

