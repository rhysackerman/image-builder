#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

export DEBIAN_FRONTEND=noninteractive

rm -rf /utemp
mkdir -p /utemp
cd /utemp

# set timezone to UTC
echo UTC > /etc/timezone
ln -s -f /usr/share/zoneinfo/UTC /etc/localtime

# fix up timezone .... not sure if there even was an issue
# anyhow this is the debian way, timedatectl and manually doing the above apparently aren't good enough for some weird debian aspects
dpkg-reconfigure --frontend noninteractive tzdata

source /etc/os-release
if (( $VERSION_ID < 11 )); then
    # only do this for old images .... not sure why we would build them
    if ! id -u pi; then
        # create pi user
        adduser pi
        adduser pi sudo
        echo "pi ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
    fi
    # set password for pi user
    echo "pi:adsb123" | chpasswd
else
    # use this idiotic way to create pi user, thank you raspbian to making the above way not work
    echo -n 'pi:' > /boot/userconf.txt && echo 'adsb123' | openssl passwd -6 -stdin >> /boot/userconf.txt
fi

# for good measure, blacklist SDRs ... we don't need these kernel modules
# this isn't really necessary but it doesn't hurt
# echo -e 'blacklist rtl2832\nblacklist dvb_usb_rtl28xxu\nblacklist rtl8192cu\nblacklist rtl8xxxu\n' > /etc/modprobe.d/blacklist-rtl-sdr.conf

systemctl disable dphys-swapfile.service
systemctl disable apt-daily.timer
systemctl disable apt-daily-upgrade.timer
systemctl disable man-db.timer

if ! grep -qs -e '/tmp' /etc/fstab; then
     sed -i -E -e 's/(vfat *defaults) /\1,noatime/g' /etc/fstab
cat >> /etc/fstab <<EOF
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=100M	0	0
tmpfs /var/log tmpfs defaults,noatime,nosuid,size=50M	0	0
tmpfs /var/lib/systemd/timers tmpfs defaults,noatime,nosuid,size=50M	0	0
EOF
fi

echo adsbfi > /etc/hostname
touch /boot/adsbfi-config.txt # canary used in some scripting if it's the ADSBfi image

mv /etc/cron.hourly/fake-hwclock /etc/cron.daily || true

pushd /etc/cron.daily
rm -f apt-compat bsdmainutils dpkg man-db
popd


# enable ssh
systemctl enable ssh

wget https://flightaware.com/adsb/piaware/files/packages/pool/piaware/f/flightaware-apt-repository/flightaware-apt-repository_1.1_all.deb
sudo dpkg -i flightaware-apt-repository_1.1_all.deb

#curl https://install.zerotier.com  -o install-zerotier.sh
#sed -i -e 's#while \[ ! -f /var/lib/zerotier-one/identity.secret \]; do#\0 break#' install-zerotier.sh
#bash install-zerotier.sh

#systemctl disable zerotier-one

apt update --allow-insecure-repositories
apt remove -y g++ libraspberrypi-doc gdb
apt dist-upgrade -y --allow-unauthenticated
sudo apt-key del "CF8A 1AF5 02A2 AA2D 763B  AE7E 82B1 2992 7FA3 303E"
sudo apt-key del "A0DA 38D0 D76E 8B5D 6388  7281 9165 938D 90FD DD2E"
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 82B129927FA3303E
apt-get update -y --allow-insecure-repositories --allow-unauthenticated

temp_packages="git make gcc libusb-1.0-0-dev librtlsdr-dev libncurses-dev zlib1g-dev python3-dev python3-venv libzstd-dev"
packages="chrony librtlsdr0 lighttpd zlib1g dump978-fa soapysdr-module-rtlsdr socat netcat rtl-sdr beast-splitter libzstd1 userconf-pi"
packages+=" curl jq gzip dnsutils perl bash-builtins"

# these are less than 0.5 MB each, useful tools for various stuff
packages+=" moreutils inotify-tools cpufrequtils"

while ! apt install --no-install-recommends --no-install-suggests -y --allow-unauthenticated --fix-missing $packages $temp_packages
do
    echo --------------
    echo --------------
    echo apt install failed, lets TRY AGAIN in 10 seconds!
    echo --------------
    echo --------------
    sleep 10
done

apt purge -y flightaware-apt-repository
rm -f /etc/apt/sources.list.d/flightaware-*.list

mkdir -p /adsbfi/
rm -rf /adsbfi/update
git clone --depth 1 https://github.com/rhysackerman/adsbfi-update.git /adsbfi/update
rm -rf /adsbfi/update/.git

bash /adsbfi/update/update-adsbfi.sh

git clone --depth 1 https://github.com/rhysackerman/adsbfi-webconfig.git
pushd adsbfi-webconfig
bash install.sh
popd

bash -c "$(curl -L -o - https://github.com/wiedehopf/graphs1090/raw/master/install.sh)"
#make sure the symlinks are present for graphs1090 data collection:
#ln -snf /run/adsbfi-978 /usr/share/graphs1090/978-symlink/data - Unsure if adsbfi 978 is setup in the same way as this?
ln -snf /run/readsb /usr/share/graphs1090/data-symlink/data

bash -c "$(curl -L -o - https://github.com/wiedehopf/adsb-scripts/raw/master/autogain-install.sh)"

# rsyslog / logrotate doesn't have any easy maxsize settings .... those tools can go where the sun doesn't shine
apt remove -y $temp_packages rsyslog
apt autoremove -y
apt clean

# delete var cache
#rm -rf /var/cache/*
# Regenerate man database.
/usr/bin/mandb

sed -i -e 's#^driftfile.*#driftfile /var/tmp/chrony.drift#' /etc/chrony/chrony.conf

# config symlinks
ln -sf /boot/adsbfi-978env /etc/default/dump978-fa
ln -sf /boot/adsbfi-env /etc/default/readsb
ln -sf /boot/adsbfi-config.txt /etc/default/adsbfi

cd /
rm -rf /utemp
