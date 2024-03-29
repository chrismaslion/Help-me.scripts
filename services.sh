#!/bin/bash

while true; do
    # Display menu
    echo "Choose an option:"
    echo "1. Secure SSH"
    echo "2. Secure VSFTPD"
    echo "3. Secure FTP"
    echo "4. Secure MYSQL"
    echo "5. Secure PostgreSQL"
    echo "6. Exit"

    # Read user input
    read -p "Enter the number of your choice: " choice

    # Execute the selected option
    case $choice in
        1)
            # Option 1
            echo "You selected Option 1."
            # Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Backup sshd_config file
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Disable root login
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Enable password authentication and disable key-based authentication
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config

# Allow only specific users
read -p "Enter the usernames allowed to SSH (space-separated): " allowed_users
sed -i "/AllowUsers/c\AllowUsers $allowed_users" /etc/ssh/sshd_config

# Reload SSH service
systemctl reload ssh

echo "SSH configuration updated. Please make sure you can log in with password authentication before closing the existing SSH session."
            ;;
        2)
            # Secure VSFTPD
            echo "Securing VSFTPD..."
            # Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Install vsftpd (if not already installed)
apt-get update
apt-get install -y vsftpd

# Backup vsftpd.conf file
cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

# Configure vsftpd for a more secure setup
cat <<EOL > /etc/vsftpd.conf
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1_2=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100
allow_writeable_chroot=YES
seccomp_sandbox=NO
EOL

# Create a user for FTP and set a password
read -p "Enter the username for FTP: " ftp_user
adduser $ftp_user

# Restart vsftpd service
systemctl restart vsftpd

echo "vsftpd configured securely. Use the FTP user credentials for authentication."

            ;;
        3)
            # Secure FTP (Without VSFTD)
            echo "Securing FTP (Without VSFTD)..."
            # Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Backup ftpd.conf file (assuming vsftpd is not installed)
cp /etc/inetd.conf /etc/inetd.conf.bak

# Configure ftpd for a more secure setup
cat <<EOL > /etc/inetd.conf
ftp     stream  tcp     nowait  root    /usr/sbin/tcpd  /usr/sbin/in.ftpd -l
EOL

# Restart inetd service
systemctl restart inetd

echo "Traditional FTP configured securely."
            ;;
        4)
            # MYSQL
            echo "Securing MYSQL"
            # Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Backup MySQL configuration file
cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.bak

# Set a strong root password
mysql_root_password=$(openssl rand -base64 12)
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'mysql_native_password' BY '$mysql_root_password';"

# Remove anonymous users
mysql -e "DELETE FROM mysql.user WHERE User='';"

# Remove remote root login
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

# Remove test database and access to it
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Apply changes and restart MySQL service
systemctl restart mysql

echo "MySQL secured. Root password: $mysql_root_password"
            ;;
        5)
            # PostgreSQL
            echo "Securing PostgreSQL..."
            # Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

# Backup PostgreSQL configuration file
cp /etc/postgresql/{version}/main/postgresql.conf /etc/postgresql/{version}/main/postgresql.conf.bak

# Set a strong password for the default 'postgres' user
postgres_password=$(openssl rand -base64 12)
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$postgres_password';"

# Update authentication method to use md5 for local connections
sed -i "s/host    all             all             127.0.0.1\/32            md5/host    all             all             127.0.0.1\/32            md5/" /etc/postgresql/{version}/main/pg_hba.conf

# Disable remote connections to PostgreSQL
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = ''/" /etc/postgresql/{version}/main/postgresql.conf

# Apply changes and restart PostgreSQL service
systemctl restart postgresql

echo "PostgreSQL secured. 'postgres' user password: $postgres_password"
            ;;
        6)
            # Exit
            echo "Exiting..."
            exit 0
            ;;
        *)
            # Invalid choice
            echo "Invalid choice. Please enter a number between 1 and 6."
            ;;
    esac
done
