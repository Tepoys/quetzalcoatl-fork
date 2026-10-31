#!/bin/sh
# Harden automatic v0.0.1

# Enforce root
if ! [ "$(id -u)" = 0 ]; then
  echo "Rerun with sudo"
  exit 1
fi

# Backup important files before modification
printf "Backing up passwd and shadow"
cp -p /etc/passwd /etc/.passwd
cp -p /etc/shadow /etc/.shadow
printf " [DONE]\n"
chattr -i /etc/passwd
chattr -i /etc/shadow

##sets path of rbash users to the /rbin folder and prevent user from changing stuff
#awk -F: '$7 == "/bin/rbash" {print $6}' /etc/passwd | while read home; do
#  echo "export PATH=/rbin" >>${home}/.bash_profile
#  echo "export PATH=/rbin" >>${home}/.bashrc
#
#  chown root:root ${home}/.bashrc
#  chown root:root ${home}/.bash_profile
#  chown root:root ${home}/.profile 2>/dev/null
#  chown root:root ${home}/.bash_logout 2>/dev/null
#  chmod 744 ${home}/.bashrc
#  chmod 744 ${home}/.bash_profile
#  chmod 744 ${home}/.profile 2>/dev/null
#  chmod 744 ${home}/.bash_logout 2>/dev/null
#done

printf "Setting password for root & bluey user\n"
hashed="$1"

# printf "Received: %s\n" "$hashed"

cat $hashed >/run/secrets/bluey-password-hash
chmod 644 /etc/passwd
chmod 600 /etc/shadow

# List of users to keep unlocked
ALLOWED_USERS="nobody bluey"

echo "/bin/false file size: "
ls -lh /bin/false

# chattr +i /etc/passwd
# chattr +i /etc/shadow
# chattr +i /etc/group

shred -uf /var/tmp/pass_*
