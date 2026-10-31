#!/bin/sh
set -e

PORT_SOURCES=${PORT_SOURCES:-/var/tmp/port-sources}

IN=$(head -n1 "$PORT_SOURCES")
OUT=$(tail -n1 "$PORT_SOURCES")

download_ports=false
nuke=false

# Parse flags
while [ "$#" -gt 0 ]; do
  case "$1" in
  -h | --help)
    cat <<EOF
Usage: $0 [OPTIONS]

  -h, --help       Display this help menu
  -c, --clear      Generate rules to clear the firewall
  -d, --download   Allow outbound DNS, HTTP, and HTTPS
EOF
    exit 0
    ;;
  -c | --clear)
    nuke=true
    shift
    ;;
  -d | --download)
    download_ports=true
    shift
    ;;
  -*)
    printf 'Unknown flag: %s\n' "$1" >&2
    exit 1
    ;;
  *)
    shift
    ;;
  esac
done

# Header of generated script
cat <<'EOF'
#!/bin/sh
set -e

# Generated firewall configuration

# Reset IPv4 firewall
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

iptables -F
iptables -X
iptables -t nat -F
iptables -t mangle -F
EOF

if [ "$nuke" = true ]; then
  printf '%s\n' \
    'echo "Firewall rules cleared."'
  exit 0
fi

# Loopback and established connections
cat <<'EOF'

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Inbound rules
EOF

for port in $IN; do
  case "$port" in
  '' | *[!0-9:]*)
    printf 'Invalid inbound port: %s\n' "$port" >&2
    exit 1
    ;;
  esac

  printf 'iptables -A INPUT -p tcp --dport %s -m conntrack --ctstate NEW -j ACCEPT\n' "$port"
  printf 'iptables -A INPUT -p udp --dport %s -m conntrack --ctstate NEW -j ACCEPT\n' "$port"
done

cat <<'EOF'

# Block outbound ICMP
iptables -A OUTPUT -p icmp -j DROP

# Outbound rules
EOF

for port in $OUT; do
  case "$port" in
  '' | *[!0-9:]*)
    printf 'Invalid outbound port: %s\n' "$port" >&2
    exit 1
    ;;
  esac

  printf 'iptables -A OUTPUT -p tcp --dport %s -m conntrack --ctstate NEW -j ACCEPT\n' "$port"
  printf 'iptables -A OUTPUT -p udp --dport %s -m conntrack --ctstate NEW -j ACCEPT\n' "$port"
done

cat <<'EOF'

# Allow inbound ICMP
iptables -A INPUT -p icmp -j ACCEPT
EOF

# Additional package manager ports
if [ "$download_ports" = true ]; then
  cat <<'EOF'

# Package manager connectivity
iptables -A OUTPUT -p udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT
EOF
fi

cat <<'EOF'

# Log dropped traffic
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "DROP_INPUT "
iptables -A OUTPUT -m limit --limit 5/min -j LOG --log-prefix "DROP_OUTPUT "

# Default deny policies
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Drop invalid traffic
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A OUTPUT -m conntrack --ctstate INVALID -j DROP

# Trusted network
iptables -A INPUT -s 192.168.111.0/24 -j ACCEPT
iptables -A OUTPUT -s 192.168.111.0/24 -j ACCEPT

# Disable IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

ip6tables -P INPUT DROP
ip6tables -P OUTPUT DROP
ip6tables -P FORWARD DROP

# Save rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/iptables.rules
ip6tables-save > /etc/iptables/ip6tables.rules
EOF
