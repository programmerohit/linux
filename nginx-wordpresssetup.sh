#/bin/bash
#############
echo
echo
# Please confirm to proceed with this script
CONFIRM="n"
echo -n "Please confirm to proceed with this script. Continue? (y/N): "
read -n 1 CONFIRM_INPUT
if [ -n "$CONFIRM_INPUT" ]; then
        CONFIRM=$CONFIRM_INPUT
fi

echo
# Enter Domain Name
read -p "Enter Domain Name (Without space): " domain
read -p "Enter User Name for Domain: " User 
# check server Public IP
pubip=`curl -s http://centos-webpanel.com/webpanel/main.php?app=showip`
# Enable epel respository
yum -y install epel-release 
yum -y install wget screen      
yum -y makecache fast
yum -y install yum-utils

# Install Nginx
echo "Installing Nginx"
yum -y install nginx*
/bin/systemctl enable nginx 
/bin/systemctl start nginx
/bin/unlink /usr/share/nginx/html/index.html
touch /usr/share/nginx/html/index.html
echo "#############################"
echo "Nginx Installed"
echo "It Works! Nginx Installed :-)" > /usr/share/nginx/html/index.html
echo "#############################"
echo "check it via URL http://$pubip/index.html"
#Installing PHP 7.3
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php73
yum -y install php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo php-mbstring php-xml php-iconv php-xdebug php-fpm
/bin/systemctl stop php-fpm
sed -i 's/:9000/:9073/' /etc/php-fpm.d/www.conf
/bin/systemctl enable php-fpm
/bin/systemctl start php-fpm
yum -y remove httpd* >> httpdremoval.log
# MariaDB install   
cat > /etc/yum.repos.d/mariadb.repo <<EOF
# MariaDB 10.4 CentOS repository list - created 2019-07-03 08:40 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.4/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
enabled=1
EOF
#Install dependecies
yum -y remove MariaDB* >> mariadbremoval.log
yum -y install MariaDB MariaDB-server
# CONFIGURE MYSQL
###################
/bin/systemctl start mariadb.service
mysql_secure_installation
/bin/systemctl enable mariadb.service
cat > /root/.my.cnf <<EOF
[client]
password=$password
user=root
EOF
chmod 600 /root/.my.cnf

# Vhost Creation 
touch /etc/nginx/conf.d/$domain.conf
if ! [[ -d /home/$User/public_html ]]; then mkdir -p /home/$User/public_html ; fi
cat > /etc/nginx/conf.d/$domain.conf  << EOF
server {
  error_log /var/log/nginx/$domain_error.log warn;
listen 80;
server_name $domain www.$domain $pubip;
access_log /var/log/nginx/$domain_access.log ;
root /home/$User/public_html;
proxy_read_timeout 300;
index index.php;

#####################################################################

location ~* \.(ico|css|js|gif|jpe?g|png)(\?[0-9]+)?$ {
expires max;
add_header Pragma public;
add_header Cache-Control "public, must-revalidate, proxy-revalidate";
log_not_found off;
add_header Access-Control-Allow-Origin *;
}


#################################################################
gzip on;
gzip_static on;
gzip_vary on;
gzip_comp_level 6;
gzip_http_version 1.0;
gzip_proxied any;
gzip_min_length 1400;
gzip_buffers 16 8k;
gzip_types text/plain text/xml text/css text/js application/json application/rss+xml image/svg+xml  application/x-j$

# Disable for IE < 6 because there are some known problems
gzip_disable "MSIE [1-6].(?!.*SV1)";

##################################################

location / {

}

location ~ \.php$ {
root /home/$User/public_html;
fastcgi_split_path_info ^(.+\.php)(/.+)$;
fastcgi_pass 127.0.0.1:9073;
fastcgi_index index.php;
include fastcgi_params;

}

}
EOF
sed -i '44i fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' /etc/nginx/conf.d/$domain.conf
sed -i '45i fastcgi_param PATH_INFO $fastcgi_path_info;' /etc/nginx/conf.d/$domain.conf
sed -i '46i fastcgi_param QUERY_STRING $query_string;' /etc/nginx/conf.d/$domain.conf
sed -i '47i fastcgi_intercept_errors on;' /etc/nginx/conf.d/$domain.conf
nginxTest=$(nginx -t)
    if [[ $? -eq 0 ]]; then
        nginx -s reload || _die "Nginx couldn't be reloaded."
    else
        echo "$_nginxTest" 
    fi


   if ! [[ -d /home/$User/public_html ]]; then 
        mkdir -p /home/$User/public_html ;
   elif ! [[ -e /home/$User/public_html/index.php ]]; then
        echo "index.php is already exists"     
   else 
        echo "<?php phpinfo(); ?>" > /home/$User/public_html/index.php
        echo "index.php is created in Document Root /home/$User/public_html/"
    fi


   if ! [[ -e /var/log/nginx/$domain_error.log ]]; then
    echo  "Log files already exists"
   else 
       touch /var/log/nginx/$domain_error.log
       echo "Log file created successfully"
    fi

   if ! [[ -e /var/log/nginx/$domain_access.log ]]; then
    echo  "Log files already exists"
   else 
       touch /var/log/nginx/$domain_access.log
       echo "Log file created successfully"
    fi

echo "#############################"
echo "#  Virtual Host Created     #"
echo "#############################"
echo "Point your $domain in this $pubip"
echo "Access it via http://$domain"
# WordPress install
siteurl=http://$domain
sitename="$domain Blog"
WORDPRESS_URL="https://wordpress.org/latest.tar.gz"
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x /root/wp-cli.phar
mv /root/wp-cli.phar /usr/local/bin/wp
wget -q $WORDPRESS_URL -P /home/$User/public_html ; 
tar -zxvf /home/$User/public_html/latest.tar.gz -C /home/$User/public_html
cp -avr /home/$User/public_html/wordpress/* /home/$User/public_html
cp -avr /home/$User/public_html/wp-config-sample.php /home/$User/public_html/wp-config.php
#Create Database for WordPress User
dbname="wpadminDB$User"
dbuser="wp_admin_user$User"
dbpass=$(</dev/urandom tr -dc A-Za-z0-9 | head -c12)

mysql -u root -p$password <<EOF
DROP USER IF EXISTS '$dbname'@'localhost';
CREATE DATABASE IF NOT EXISTS $dbname;
CREATE USER IF NOT EXISTS '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';
GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';
EOF
#set database details with perl find and replace
perl -pi -e "s/database_name_here/$dbname/g" /home/$User/public_html/wp-config.php
perl -pi -e "s/username_here/$dbuser/g" /home/$User/public_html/wp-config.php
perl -pi -e "s/password_here/$dbpass/g" /home/$User/public_html/wp-config.php
#create uploads folder and set permissions
wpuser="$User"
wppass="$domain@123"
wpemail=admin@$domain
mkdir -p /home/$User/public_html/wp-content/uploads
chmod 777 /home/$User/public_html/wp-content/uploads
echo
echo "Installing wordpress..."
wp core install --path="/home/$User/public_html/" --url="$siteurl" --title="$sitename" --admin_user="$wpuser" --admin_password="$wppass" --admin_email="$wpemail"

echo "#############################"
echo "#  WordPress Installed       #"
echo "#############################"
echo "Your WordPress Username is : $wpuser"
echo "Your WordPress Password is : $wppass"
echo "Access it via http://$domain"
