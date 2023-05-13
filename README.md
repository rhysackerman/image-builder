# image-builder

## Building the ADSBfi image based on buster:

```
git clone https://github.com/rhysackerman/image-builder.git
cd image-builder
wget https://downloads.raspberrypi.org/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2021-12-02/2021-12-02-raspios-buster-armhf-lite.zip
unzip 2021-12-02-raspios-buster-armhf-lite.zip
 ./create-image.sh 2021-12-02-raspios-buster-armhf-lite.img buster.img
```

## Building the ADSBfi image base on bullseye

```
wget https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz
unxz 2023-05-03-raspios-bullseye-armhf-lite.img.xz
./create-image.sh 2023-05-03-raspios-bullseye-armhf-lite.img bullseye.img
```

## tracking down disk writes

```
stdbuf -oL -eL inotifywait -r -m /etc /adsbfi /opt /root /home /usr /lib /boot /var 2>&1 | stdbuf -oL grep -v -e OPEN -e NOWRITE -e ACCESS -e /var/tmp -e /var/cache/fontconfig -e /var/lib/systemd/timers -e /var/log | ts >> /tmp/inot
```
