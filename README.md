# digital-ocean
Scripts for Automatic setup on Digital Ocean

# setup.sh 
Works on Ubuntu 16.04 up to 18.04 and provides a new user account and automatically sets this up with ssh-keys taken from the root account when you add them into the creation of your droplet.

# It also runs the following:
    apt update and upgrade.
    setting of timezone to London
    adds user to sudoers and removes requirment for password
    disables logins with password, allows only ssh-key login
    configures a swap drive

# Security changes    
    restricts su
    changes ssh port to specified for security
    install csf and configures all of the IP ban lists
    sets up hosts.allow with your IP
    sets up csf with your IP
    

# setup-nginx.sh 
Does the same as setup.sh except it also adds in csf values to make csf respond like fail2ban for nginx hack attempts for nginx and wordpress running on nginx. Also adds cloudflare API key if you have one.
