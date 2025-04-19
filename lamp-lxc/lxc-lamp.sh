#!/bin/bash
# Project development environment initialization
#
# LAMP stack on LXC: Ubuntu, Apache, MySQl, PHP, PHPMyAdmin.
# This script is not fully automated, but help you a lot to setup LAMP stack in LXC. Just run it and follow instruction. I will update it regularly.
#
# Author: Vu Ngoc Binh 

# Edit constant here
UBUNTU_VERSION="noble"
MYSQL_USERNAME="binh"
MYSQL_PASSWORD="binh"

# Any subsequent(*) commands which fail will cause the shell script to exit immediately
set -e

LXC_NAME=$1
DB_NAME=$1

LXC_PATH="/var/lib/lxc/${LXC_NAME}"
LXC_ROOT="/var/lib/lxc/${LXC_NAME}/rootfs"

[ -z "$LXC_NAME" ] && echo "Hey, tell me plz container name. Example: $ sudo ./lxc-lamp.sh myapp" && exit 1



# Require sudo to run script
if [ -z ${SUDO_UID+x} ]; then
  echo "Hm, run this script using sudo plz:"
  echo "$ sudo ./initenv.sh [container-name]"
  exit 255
fi

# SUDO_USER is original user name of developer
# check that $SUDO_USER != 'root'
if [ "$SUDO_USER" = "root" ]; then
    echo "Not root plz. Swithch to user you working as, then run it"
    exit 255
fi

MY_GROUP=`id -gn $SUDO_USER`

# Remove old container and create new one.
if lxc-ls -f | grep "${LXC_NAME}"; then
  read -p "Container '${LXC_NAME}' already exists. Destroy it, and create new one from scratch (y/n)? " CONT
  if [ "$CONT" = "y" ]; then
    lxc-destroy -n "${LXC_NAME}" -f;
  else
    echo "Exiting...";
    exit 1;
  fi

fi

# Container creation: Ubuntu 24.04
echo "Creating container: ${LXC_NAME}"
lxc-create -t download -n "${LXC_NAME}" -- -d ubuntu -r ${UBUNTU_VERSION} -a amd64

# Lxc config tweaks
{
  echo ""
  echo "# Map Host project directory to /www"
  echo "lxc.mount.entry = ${PWD} var/www/${LXC_NAME} none bind,create=dir,rw 0 0"
} >> "${LXC_PATH}/config"

echo "Starting ${LXC_NAME}...";
lxc-start -n "${LXC_NAME}"

# Recreate default user, his login, uid, gid equal to host user
lxc-attach -n "${LXC_NAME}" -- userdel -r ubuntu
lxc-attach -n "${LXC_NAME}" -- groupadd -g ${SUDO_GID} ${MY_GROUP}
lxc-attach -n "${LXC_NAME}" -- useradd -s /bin/bash --gid ${SUDO_GID} -G sudo --uid ${SUDO_UID} -m ${SUDO_USER}

# wait untill it starts
until [[ `lxc-ls -f | grep "${LXC_NAME}" | grep "RUNNING" | grep "10.0.3"` ]]; do sleep 1; done;
#echo `lxc-ls -f`

# Packages installation
echo "Packages installation...";

## Predefined variables to install postfix
## https://blog.bissquit.com/unix/debian/postfix-i-dovecot-v-kontejnere-docker/
{
  echo "postfix postfix/main_mailer_type string Internet site"
  echo "postfix postfix/mailname string mail.domain.tld"
} >> "${LXC_ROOT}/tmp/postfix_silent_install.txt"

lxc-attach -n "${LXC_NAME}" -- debconf-set-selections /tmp/postfix_silent_install.txt

# Update repository
lxc-attach -n "${LXC_NAME}" -- apt update
# I don't know why I need it.
lxc-attach -n "${LXC_NAME}" -- sh -c "DEBIAN_FRONTEND=noninteractive apt install -q -y locales-all"
# Install nano for easier config later, if needed
lxc-attach -n "${LXC_NAME}" -- sh -c "DEBIAN_FRONTEND=noninteractive apt install -q -y nano"

# Install apache and mysql
lxc-attach -n "${LXC_NAME}" -- sh -c "DEBIAN_FRONTEND=noninteractive apt install -q -y apache2 mysql-server"  # sphinxsearch
# Follow the instruction.

# Secure your installation. Don't set password validation because of conflict with phpMyAdmin
lxc-attach -n "${LXC_NAME}" -- sudo mysql_secure_installation;

# Install php
lxc-attach -n "${LXC_NAME}" -- sh -c "DEBIAN_FRONTEND=noninteractive apt install -q -y php libapache2-mod-php php-mysql php-cli";

# Setup apache to prioritize php script.
{
cat << EOFAPACHE
<IfModule mod_dir.c>
		DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
</IfModule> 
EOFAPACHE
} > "${LXC_ROOT}/etc/apache2/mods-enabled/dir.conf";

# Restart apache
lxc-attach -n "${LXC_NAME}" -- sudo systemctl restart apache2;

# Create new directory and set chown to serve files successfully.
lxc-attach -n "${LXC_NAME}" -- sudo mkdir -p /var/www/${LXC_NAME};

lxc-attach -n "${LXC_NAME}" -- sudo chown -R $USER:$USER /var/www/${LXC_NAME};

# Config Virtual host at port 80
{
cat <<EOFAPACHE
<VirtualHost *:80>
    ServerName your_domain
    DocumentRoot /var/www/${LXC_NAME}
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOFAPACHE
} > "${LXC_ROOT}/etc/apache2/sites-available/${LXC_NAME}.conf";

# Enable the virtual host and reload apache
lxc-attach -n "${LXC_NAME}" -- sudo a2ensite ${LXC_NAME};

lxc-attach -n "${LXC_NAME}" -- sudo a2dissite 000-default;

lxc-attach -n "${LXC_NAME}" -- sudo systemctl reload apache2;

# Install phpMyAdmin 
lxc-attach -n "${LXC_NAME}" -- sh -c "sudo apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl"
# Follow the instruction

lxc-attach -n "${LXC_NAME}" -- sudo phpenmod mbstring;

lxc-attach -n "${LXC_NAME}" -- sudo systemctl restart apache2;

lxc-attach -n "${LXC_NAME}" -- sudo mysql -e "CREATE USER '${MYSQL_USERNAME}'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${MYSQL_PASSWORD}'";

lxc-attach -n "${LXC_NAME}" -- sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USERNAME}'@'localhost' WITH GRANT OPTION";

# Help messages
LXC_IP=`lxc-info -n ${LXC_NAME} -iH`

echo
echo "======================= HA, ALL DONE! ==========================="
echo
echo "Open in browser: http://${LXC_IP}"
echo
echo "Your database name: {$DB_NAME} (user: ${MYSQL_USERNAME}, passw: ${MYSQL_PASSWORD})"
echo "                    Accesible from inside container only. From localhost."
echo
echo "To start adminer run: http://${LXC_IP}/phpmyadmin"
echo
echo "Hope to be helpful. Happy coding :o)"
