#!/bin/bash

#Gitorious Ubuntu 12.04 Server Post-install Script
# Thanks to Lucas Jenß ( for initial instructions @ http://coding-journal.com/author/x3ro/)

#Authors:
# Ezra Bowden - V1 - http://blog.kyodium.net
#	- Initial Script
#	- Working with 11.04

# Nathan Hold - V2 - https://github.com/nhold/
#	- Code cleanup
# 	- Working with 12.04

# Starts with a base 12.04 server installation, no packages/groups added during OS installation.
# It's best to install the server, then ssh in and run the script because there's a couple of steps
# that'll be much easier if you can copy/paste.

# Running this script as root (sudo sh <scriptname>) against a base 12.04 server install should
# have you up and running without any additional fiddling around. Let me know if you see a better way
# to do this, or find any glaring errors.

# VARIABLES:
PARAMETERS="[-d|--debug] [-h|--help] [-u|--git-db-user <user>] [-p|--git-db-password <password>]"
SPHINX_URL="http://sphinxsearch.com/files/sphinx-0.9.9.tar.gz"
GITORIOUS_REPO="git://gitorious.org/gitorious/mainline.git"

APTCMD="aptitude install -y"
PACKAGES="build-essential zlib1g-dev tcl-dev libexpat-dev \
    libcurl4-openssl-dev postfix apache2 mysql-server mysql-client \
    apg geoip-bin libgeoip1 libgeoip-dev sqlite3 libsqlite3-dev \
    imagemagick libpcre3 libpcre3-dev zlib1g zlib1g-dev libyaml-dev \
    libmysqlclient15-dev apache2-dev libonig-dev ruby-dev rubygems \
    libopenssl-ruby libdbd-mysql-ruby libmysql-ruby \
    libmagick++-dev zip unzip memcached git-core git-svn git-doc \
    git-cvs irb"

HOSTNAME=`hostname --fqdn`
GIT_DB_PASS="gitorious"
GIT_DB_USER="gitorious"


# PARAMETER CHECK
while [ $# -gt 0 ]; do    # Until you run out of parameters ...
  case "$1" in
     	-d|--debug)
          	# "-d" or "--debug" parameter?
          	DEBUG=1
		APTCMD=`echo "$APTCMD" | sed '/.*/ s/[ ]-y//'`
          	;;
	-u|--git-db-user)
	      	shift
		GIT_DB_USER="$1"
              	;;
	-p|--git-db-password)
		shift
		GIT_DB_PASS="$1"
		;;
	*)	
		echo "\n"
	      	echo "Usage: `basename $0` $PARAMETERS"
		echo "\n"
		echo "Running this script as root (sudo sh `basename $0`) against a base 10.10 server install should"
		echo "have you up and running without any additional fiddling around. Let me know if you see a better way"
		echo "to do this, or any glaring errors."
		echo "\n"
		exit 0
	      	;;
  esac
  shift       # Check next set of parameters.
done


# Install packages:
$APTCMD $PACKAGES


# Install ruby gems:
REALLY_GEM_UPDATE_SYSTEM=1 gem update --system

gem install --no-ri --no-rdoc -v 0.8.7 rake && \
    gem install --no-ri --no-rdoc -v 1.1.0 daemons && \
    gem install -b --no-ri --no-rdoc \
        rmagick stompserver passenger bundler


# Install sphinx search server:
cd /usr/src
FILE=`echo "$SPHINX_URL" | sed 's/^\(.*\)\/\(.*\)\(\.tar\.gz\)/\2\3/'`
if [ -e $FILE ]; then 
	echo "Local copy of $FILE exists, Skipping download."
else
	wget "$SPHINX_URL"
fi
echo "Extracting $FILE..."
tar -xzvf $FILE
cd `echo "$FILE" | sed 's/^\(.*\)\(\.tar\.gz\)/\1/'` && \
	./configure --prefix=/usr && \
	make all install


# Install gitorious:
git clone $GITORIOUS_REPO /var/www/gitorious
ln -s /var/www/gitorious/script/gitorious /usr/bin


# Configure services:
cd /var/www/gitorious/doc/templates/ubuntu/ && \
    cp git-daemon git-poller git-ultrasphinx stomp /etc/init.d/ && \
    cd /etc/init.d/ && \
    chmod 755 git-daemon git-poller git-ultrasphinx stomp

update-rc.d git-daemon defaults && \
    update-rc.d git-poller defaults && \
    update-rc.d git-ultrasphinx defaults && \
    update-rc.d stomp defaults

ln -s /usr/ /opt/ruby-enterprise


# Configure Apache for Passenger:
echo "\a\a"
$(gem contents passenger | grep passenger-install-apache2-module)

echo "\a\a"
echo "\n\nWe are going to enter the 3 lines from the above prompt: \"The Apache 2 module was successfully installed.\""
echo "into passenger.load. Scroll up and copy the lines then press enter to continue."
echo "They should look similar to this:\n"
echo "   LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-3.0.9/ext/apache2/mod_passenger.so"
echo "   PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-3.0.9"
echo "   PassengerRuby /usr/bin/ruby1.8"
echo "\n"
read -p "[Press Enter to continue]" null
nano /etc/apache2/mods-available/passenger.load


# Enable modules:
a2enmod passenger && \
    a2enmod rewrite && \
    a2enmod ssl


# Create gitorious sites:
FILE="/etc/apache2/sites-available/gitorious"
echo "<VirtualHost *:80>" >> $FILE
echo "   ServerName your.server.com" >> $FILE
echo "   DocumentRoot /var/www/gitorious/public" >> $FILE
echo "</VirtualHost>" >> $FILE

FILE="/etc/apache2/sites-available/gitorious-ssl"
echo "<IfModule mod_ssl.c>" >> $FILE
echo "    <VirtualHost _default_:443>" >> $FILE
echo "        DocumentRoot /var/www/gitorious/public" >> $FILE
echo "        SSLEngine on" >> $FILE
echo "        SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem" >> $FILE
echo "        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key" >> $FILE
echo "        BrowserMatch ".*MSIE.*" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0" >> $FILE
echo "    </VirtualHost>" >> $FILE
echo "</IfModule>" >> $FILE


# Disable default site and enable gitorious sites:
a2dissite default && \
    a2dissite default-ssl && \
    a2ensite gitorious && \
    a2ensite gitorious-ssl


# Create mysql user:
start mysql
echo "\a\a"
echo "!!!!!!!!!!     The next password prompt is for the MySQL root password you set previously.     !!!!!!!!!!"
echo "\n"
mysql -u root -p <<HERE
GRANT ALL PRIVILEGES ON *.* TO '$GIT_DB_USER'@'localhost' IDENTIFIED BY '$GIT_DB_PASS' WITH GRANT OPTION;
FLUSH PRIVILEGES;
quit
HERE


# Configure gitorious:
cd /var/www/gitorious/ && \
    bundle install

adduser --system --home /var/www/gitorious/ --no-create-home --group --shell /bin/bash git && \
    chown -R git:git /var/www/gitorious

su - git -c "mkdir .ssh && \
    touch .ssh/authorized_keys && \
    chmod 700 .ssh && \
    chmod 600 .ssh/authorized_keys && \
    mkdir tmp/pids && \
    mkdir repositories && \
    mkdir tarballs"


# Create gitorious configuration:
su - git -c "cp config/database.sample.yml config/database.yml && \
    cp config/gitorious.sample.yml config/gitorious.yml && \
    cp config/broker.yml.example config/broker.yml"


# Edit database user in database.yml
FILE="/var/www/gitorious/config/database.yml"
sed -i -n '1h;1!H;${;g;s/\(production:.*\)\(\n[ \t]*username:\).*\n\([ \t]*password:\).*\n\([ \t]*host:\)/\1\2 '$GIT_DB_USER'\n\3 '$GIT_DB_PASS'\n\4/g;p;}' $FILE


# Edit gitorious configuration:
FILE="config/gitorious.yml"

su - git -c "sed -i 's/^production:/&\n\
  repository_base_path: \/var\/www\/gitorious\/repositories\n\
  gitorious_client_host: localhost\n\
  gitorious_client_port: 80\n\
  gitorious_host: $HOSTNAME\n\
  archive_cache_dir: \/var\/www\/gitorious\/tarballs\n\
  archive_work_dir: \/tmp\/tarballs-work\n\
  hide_http_clone_urls: true\n\
  is_gitorious_dot_org: false/' $FILE"

echo "\a\a"
echo "You will need a secret key for verifying cookie session data."
echo "If you change this key, all old sessions will become invalid."
read -p "Enter a key of 30 random characters or more: " SECRET_KEY
FILE="config/environment.rb"

su - git -c "sed -i 's/^[ \t]*#[ \t]*no regular words .*/&\n  config.action_controller.session = { :key => \"_myapp_session\", :secret => \"$SECRET_KEY\" }/' $FILE"
su - git -c "sed -i '/config.action_controller.session_store/ s/^\([ \t]*\)#/\1/' $FILE"


# Create gitorious database:
su - git -c "mv config/boot.rb config/boot.bak"
su - git -c "echo \"require 'thread'\" >> config/boot.rb"
su - git -c "cat config/boot.bak >> config/boot.rb"

su - git -c "export RAILS_ENV=production && \
   bundle exec rake db:create && \
   bundle exec rake db:migrate && \
   bundle exec rake ultrasphinx:bootstrap"


# Create sphinx cronjob:
echo "\a\a"
echo "Copy the line below and paste into crontab when it opens:\n"
echo "* * * * * cd /var/www/gitorious && /usr/bin/bundle exec rake ultrasphinx:index RAILS_ENV=production\n"
read -p "[Press Enter to continue]" null
su - git -c "crontab -e"

su - git -c "env RAILS_ENV=production ruby1.8 script/create_admin"

# Finished!
echo "\a\a"
echo "Gitorious installed successfully."
echo "System will now reboot.\n"
read -p "[Press Enter to continue]" null
reboot

