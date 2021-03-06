#!/bin/sh

# This sets up RMC web app on EC2 Ubuntu11 AMI.
#
# Idempotent.
#
# This can be run like
#
# $ cat setup.sh | ssh <hostname of EC2 machine> sh
#
# But first, make sure you've attached an EBS volume to the instance for
# persistent, duplicated storage that survives reboots. Then, run
#
# ./create_role_account.sh rmc | ssh -i KEYFILE ubuntu@IP_ADDRESS sh
#
# to create the "rmc" user account.


# Bail on any errors
set -e

CONFIG_DIR=$HOME/rmc/aws_setup

cd $HOME

sudo apt-get update

echo "Installing developer tools"
sudo apt-get install -y curl
sudo apt-get install -y python-pip
sudo apt-get install -y build-essential python-dev
sudo apt-get install -y git
sudo apt-get install -y unzip
sudo apt-get install -y ruby rubygems
sudo REALLY_GEM_UPDATE_SYSTEM=1 gem update --system

sudo pip install virtualenv
mkdir -p /home/rmc/.virtualenvs
RMC_VIRTUALENV_DIR=/home/rmc/.virtualenvs/rmc
virtualenv --no-site-packages "$RMC_VIRTUALENV_DIR"
. "$RMC_VIRTUALENV_DIR"/bin/activate

echo "Prepping EBS mount points"
sudo mkdir -p /ebs/data
sudo chown $USER /ebs/data
ln -sf /ebs/data

cat <<EOF

# Format the EBS volume if attaching a new disk with nothing in it. You'll
# have to look up the device file (eg. /dev/xvdf) in EC2 console and ls /dev
sudo mkfs.ext3 /dev/xvdf

# If this is your first time setting up the machine, you'll need to add
# something like the following to /etc/fstab, then reboot from AWS console:
/dev/xvdf    /ebs/data         auto	defaults,comment=cloudconfig	0	2

# See for more info:
# http://yoodey.com/how-attach-and-mount-ebs-volume-ec2-instance-ubuntu-1010

# Also if this is the first time setting up the machine, run something like:
scp ~/.ssh/id_dsa* rmc:~/.ssh/

EOF

echo "Syncing rmc code base"
git clone git@github.com:UWFlow/rmc.git || ( cd rmc && git pull )

echo "Copying dotfiles"
for i in $CONFIG_DIR/dot_*; do
  cp "$i" ".`basename $i | sed 's/dot_//'`";
done

echo "Creating logs directory"
mkdir -p data/logs
ln -sf data/logs

# TODO(david): Use prod_mongodb.conf
echo "Setting up mongodb and installing as a daemon"

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
sudo rm -rf /etc/apt/sources.list.d/10gen.list
sudo /bin/sh -c 'echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" > /etc/apt/sources.list.d/10gen.list'
sudo apt-get update
sudo apt-get install -y mongodb-10gen
sudo killall mongod || true
sudo rm -f /etc/init/mongodb.conf  # Remove annoying upstart daemon to install ours
sudo update-rc.d -f mongo_daemon remove
sudo ln -sfnv $CONFIG_DIR/etc/init.d/mongo_daemon /etc/init.d
sudo update-rc.d mongo_daemon defaults
sudo service mongo_daemon restart

echo "Setting up redis and installing as a daemon"
# TODO(david): Should actually make and build a specific version
sudo add-apt-repository -y ppa:rwky/redis
sudo apt-get update
sudo apt-get install -y redis-server
mkdir -p /home/rmc/data/redis/
# TODO(david): Do this better (redis daemon changes user to redis)
chmod a+w /home/rmc/data/redis/
chmod a+w /home/rmc/data/logs/
sudo rm -f /etc/init/redis-server.conf  # Remove annoying upstart daemon
sudo service redis-server stop  # Stop so we can start redis using our config
sudo update-rc.d -f redis-server remove
sudo ln -sfnv $CONFIG_DIR/etc/init.d/redis-server /etc/init.d
sudo update-rc.d redis-server defaults
sudo service redis-server start

echo "Installing nginx"
sudo add-apt-repository -y ppa:nginx/stable
sudo apt-get update
sudo apt-get install -y nginx
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sfnv $CONFIG_DIR/etc/nginx/sites-available/rmc \
  /etc/nginx/sites-available/rmc
sudo ln -sfnv /etc/nginx/sites-available/rmc /etc/nginx/sites-enabled/rmc
sudo service nginx restart

echo "Installing node and npm"
sudo apt-get install -y python-software-properties
sudo add-apt-repository -y ppa:chris-lea/node.js
sudo apt-get update -y
sudo apt-get install -y nodejs npm

echo "Setting up rmc and dependencies"
# TODO(david): Call setup_ubuntu.sh
# Install libraries needed for lxml
sudo apt-get install -y libxml2-dev libxslt-dev
# Setup compass
sudo gem install compass
( cd rmc/server && compass init --config config.rb )
# Setup bundle
sudo gem install rdoc
sudo gem install bundle
sudo gem install rdoc-data; sudo rdoc-data --install
( cd rmc/server && bundle install )
# Install pip requirements: sudo because we don't set up virtualenv
( cd rmc && pip install -r requirements.txt )
# Import data from various text files
( cd rmc && make init_data )
mkdir -p /home/rmc/logs/server

echo "Setting up rmc web server as a daemon"
sudo update-rc.d -f rmc_daemon remove
sudo ln -sfnv $CONFIG_DIR/etc/init.d/rmc_daemon /etc/init.d
sudo update-rc.d rmc_daemon defaults
sudo service rmc_daemon start

echo "Setting up celery as a daemon"
sudo update-rc.d -f celeryd remove
sudo ln -sfnv $CONFIG_DIR/etc/default/celeryd /etc/default
sudo ln -sfnv $CONFIG_DIR/etc/init.d/celeryd /etc/init.d
sudo update-rc.d celeryd defaults
sudo service celeryd start

echo "Installing crontab"
sudo apt-get install -y mailutils
crontab $CONFIG_DIR/crontab

echo "Installing phantomjs"
(
    cd /usr/local/share
    case `uname -m` in
        i?86) mach=i686;;
        *) mach=x86_64;;
    esac
    sudo rm -rf phantomjs
    wget "https://phantomjs.googlecode.com/files/phantomjs-1.9.2-linux-${mach}.tar.bz2" -O- | sudo tar xfj -

    sudo ln -snf /usr/local/share/phantomjs-1.9.2-linux-${mach}/bin/phantomjs /usr/local/bin/phantomjs
)
