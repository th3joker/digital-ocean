#!/bin/bash

# Set Variables
# My IP
myip=$(echo $SSH_CLIENT | awk '{ print $1}')

# Get username and set as variable
echo "Please enter username:"
read -p 'Username: ' username
# Get fullname and set as variable
echo "Please enter your Full Name:"
read -p 'Fullname: ' fullname

# secure tmpfs
sed -i 's/tmpfs defaults,/tmpfs defaults,noexec,nosuid,/g' /etc/fstab;

# Harden networking layer
echo -e "# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf;

# Set SSH port number
# Get username and set as variable
echo "Please enter SSH port number, we recommend above 50000 "
read -p 'Port Number: ' sshport


# set locale
export LANGUAGE=en_US.UTF-8;
export LC_ALL=en_US.UTF-8;
export LANG=en_US.UTF-8;
export LC_TYPE=en_US.UTF-8;

# run apt update and upgrade
apt-get update;
apt-get upgrade -y;

# Install ClamAV
apt-get install clamav -y;
echo -e "02 1 * * * root clamscan -R /var/www" >> /var/spool/cron/crontabs/root;

# Install Unzip
apt-get install unzip -y;

# Set timezone Europe/London #
echo "Europe/London" | sudo tee /etc/timezone;
sudo dpkg-reconfigure --frontend noninteractive tzdata;

## Add User $username ##
echo "Adding user $username"
useradd $username -G sudo -d /home/$username -s /bin/bash -m -c "$fullname";

## Add to sudoers ##
echo "Assign $username to sudoers"
echo "$username	ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers;
echo " adding ssh keys for $username"

## Add ssh keys ##
mkdir /home/$username/.ssh && ssh-keygen -t rsa -N "" -f /home/$username/.ssh/id_rsa
cp /root/.ssh/authorized_keys /home/$username/.ssh/;
chown -R $username:$username /home/$username/.ssh;

## add group admin ##
addgroup admin;
adduser $username admin;

## restrict su ##
sudo dpkg-statoverride --update --add root admin 4750 /bin/su;

## secure /run/shm ##
echo "tmpfs /run/shm tmpfs defaults,noatime,size=20%,mode=1777 0 0" >> /etc/fstab;

## Add .profile ##
echo -e 'PS1="`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[$(tput bold)\]\[$(tput setaf 6)\]\t \[$(tput setaf 2)\][\[$(tput setaf 5)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 5)\]\H \[$(tput setaf 6)\]\W\[$(tput setaf 2)\]]\[$(tput setaf 6)\] ;-)\n\\$ \[$(tput sgr0)\]"' >> /home/$username/.profile;
echo -e 'PS1="`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[$(tput bold)\]\[$(tput setaf 6)\]\t \[$(tput setaf 2)\][\[$(tput setaf 5)\]\u\[$(tput setaf 2)\]@\[$(tput setaf 5)\]\H \[$(tput setaf 6)\]\W\[$(tput setaf 2)\]]\[$(tput setaf 6)\] ;-)\n\\$ \[$(tput sgr0)\]"' >> /root/.profile;

## bashrc aliases ##
echo "alias sudos='sudo su --login'
alias apti='sudo apt-get install'
alias aptr='sudo apt-get remove'" >> /home/$username/.bashrc;

## change ssh options, port 55022, no root logins and ssh key only ##
echo "Changing sshd service options to port $sshport, no root logins and ssh key only"
sed -i "s/#Port 22/Port $sshport/g" /etc/ssh/sshd_config;
sed -i "s/Port 22/Port $sshport/g" /etc/ssh/sshd_config;
sed -i "s/PermitRootLogin yes/PermitRootLogin without-password/g"  /etc/ssh/sshd_config;
sed -i "s/#\PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config;
service ssh restart;

# Hosts allow file
# input IP for hosts.allow
echo "ALL : $myip  : allow" | tee /etc/hosts.allow;

# Add hosts deny info
echo "#DENY LIST
sshd : ALL : deny
whostmgrd : ALL : deny
ftpd : ALL : deny
mysqld : ALL : deny" >> /etc/hosts.allow;


# Install CSF
cd /usr/local/src;
wget http://download.configserver.com/csf.tgz;
ufw disable;
tar zxvf csf.tgz;
cd csf;
./install.sh;

#Insert ip into ignore and allow
echo "$myip # $username" | tee /etc/csf/csf.allow /etc/csf/csf.ignore;
sed -i 's/TESTING = "1"/TESTING = "0"/g' /etc/csf/csf.conf;
sed -i 's/#SPAMDROP/SPAMDROP/g' /etc/csf/csf.blocklists;
sed -i 's/#SPAMEDROP/SPAMEDROP/g' /etc/csf/csf.blocklists;
sed -i 's/#DSHIELD/DSHIELD/g' /etc/csf/csf.blocklists;
sed -i 's/#TOR/TOR/g' /etc/csf/csf.blocklists;
sed -i 's/#ALTTOR/ALTTOR/g' /etc/csf/csf.blocklists;
sed -i 's/#BOGON/BOGON/g' /etc/csf/csf.blocklists;
sed -i 's/#HONEYPOT/HONEYPOT/g' /etc/csf/csf.blocklists;
sed -i 's/#CIARMY/CIARMY/g' /etc/csf/csf.blocklists;
sed -i 's/#BFB/BFB/g' /etc/csf/csf.blocklists;
sed -i 's/#MAXMIND/MAXMIND/g' /etc/csf/csf.blocklists;
sed -i 's/#BDEALL/BDEALL/g' /etc/csf/csf.blocklists;
sed -i 's/#STOPFORUMSPAM/STOPFORUMSPAM/g' /etc/csf/csf.blocklists;
sed -i 's/#STOPFORUMSPAMV6/STOPFORUMSPAMV6/g' /etc/csf/csf.blocklists;
sed -i 's/#GREENSNOW/GREENSNOW/g' /etc/csf/csf.blocklists;

# check port open in csf.conf
sed -i "s/20,21,22,25,53,80,110,143,443,465,587,993,995/20,21,22,25,53,80,110,143,443,465,587,993,995,$sshport/g" /etc/csf/csf.conf;

# Restart CSF
csf -r;

# Install Root Kit Hunter
apt-get install rkhunter -y;
# fix rkhunter update bug
sed -i 's/UPDATE_MIRRORS=0/UPDATE_MIRRORS=1/g' /etc/rkhunter.conf;
sed -i 's/MIRRORS_MODE=1/MIRRORS_MODE=0/g' /etc/rkhunter.conf;
sed -i 's\WEB_CMD="/bin/false"\WEB_CMD=""\g' /etc/rkhunter.conf;
# add crontab to run rootkit hunter
echo -e "# run rootkit hunter
15 04 * * * /usr/bin/rkhunter --cronjob --update --quiet" >> /var/spool/cron/crontabs/root;

#creating of swap
echo -e "On next step we going to create SWAP (it should be your RAM x2)..."

read -r -p "Do you need SWAP? [y/N] " response
case $response in
    [yY][eE][sS]|[yY]) 

  RAM="`free -m | grep Mem | awk '{print $2}'`"
  swap_allowed=$(($RAM * 2))
  swap=$swap_allowed"M"
  fallocate -l $swap /var/swap.img
  chmod 600 /var/swap.img
  mkswap /var/swap.img
  swapon /var/swap.img

  echo -e "${GREEN}RAM detected: $RAM
  Swap was created: $swap${NC}"
  sleep 5

        ;;
    *)

  echo -e "${RED}You didn't create any swap for faster system working. You can do this manually or re run this script.${NC}"

        ;;
esac

apt-get autoremove -y;

# Password stuff
echo "Adding password for $username"
## add user password ##
echo "Please enter the new password:"
read -s password1
echo "Please repeat the new password:"
read -s password2
# Check both passwords match
if [ $password1 != $password2 ]; then
    echo "Passwords do not match"
     exit
fi

# Change password
echo -e "$password1\n$password1" | passwd $username


# Check Script
echo "Hosts Allow Check"
cat /etc/hosts.allow;

echo "csf.ignore Check"
cat /etc/csf/csf.ignore;

echo "csf.allow Check"
cat /etc/csf/csf.allow;


