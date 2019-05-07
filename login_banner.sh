#!/bin/bash

#===================================================================================
#
#          FILE:  login_banner.sh
#
#   DESCRIPTION:  Adds a banner to the login screen.
#
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Eleanor Coyle, coyleej@protonmail.com
#       COMPANY:  Azimuth Corporation
#       VERSION:  1.0
#       CREATED:  2019-05-06
#      REVISION:  2019-05-07
#
#===================================================================================
 
# Disable wayland or it kills the nvidia drivers
customConf=/etc/dgm3/custom.conf
sudo sed -i.bak -e "/WaylandEnable/ s/^#//" $customConf

if ( ! grep "^WaylandEnable=false" $customConf ); then
	echo "Error: "$customConf" did not update successfully!"
	echo "Error: Wayland is still enabled, will cause login issues!"
	echo ""
fi

# Create directory and files
gdmProfile=/etc/dconf/profile/gdm
gdmDir=/etc/dconf/db
gdmBanner=$gdmDir/01-banner-message

sudo touch $gdmProfile
sudo mkdir $gdmDir
sudo touch $gdmBanner

# Create dconf profile
sudo echo "user-db:user" > $gdmProfile
sudo echo "system-db:gdm" >> $gdmProfile
sudo echo "file-db:/usr/share/gdm/greeter-dconf-defaults" >> $gdmProfile

# Create banner message
sudo echo "[org/gnome/login-screen]" > $gdmBanner
sudo echo "banner-message-enable=true" >> $gdmBanner
sudo echo "banner-message-text='I have read & consent to terms in IS user agreement.'" >> $gdmBanner

# Reconfigure things
sudo dconf update
sudo dpkg-reconfigure gdm3

# Notify user that a reboot is required.
echo "This workstation must be restarted for these changes to take effect"
