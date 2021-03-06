#!/bin/bash

#===================================================================================
#
#          FILE:  slurmdb_initial_setup.sh
#
#   DESCRIPTION:  Adjusts slurm config files for slurm database installation for 
#                 Ubuntu 18.04, must have slurm already installed and running
#
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Eleanor Coyle, ecoyle@azimuth-corp.com
#       COMPANY:  Azimuth Corporation
#       VERSION:  1.0
#       CREATED:  2019-02-13
#      REVISION:  2019-04-25
#
#===================================================================================

echo "This code assumes slurm was set up with install_slurm.sh"

#### Creating log and pid files ####
logDir=/var/log
logFile=$logDir/slurmd.log
sudo touch $logFile
sudo chown slurm: $logFile

pidDir=/var/run/slurm-llnl
pidFile=$pidDir/slurmdbd.pid
sudo touch $pidFile
sudo chown slurm: $pidFile

echo "hello"

# Does slurmdbd not need a spool directory?

#### Config files ####

ctlname=$( scontrol show config | grep ControlMachine | awk '{print $3}' )
ctladdr=$( scontrol show config | grep ControlAddr | awk '{print $3}' )

echo "hi"

# Edit slurm.conf
cd /etc/slurm-llnl/
slurmConf="slurm.conf"
sudo cp $slurmConf $slurmConf.backup

sudo chown $USER: $slurmConf $slurmConf.backup

echo "howdy"

sudo sed -i -e "/#JobAcctGatherType=/ s/#//" \
	-e "/#JobAcctGatherFrequency=/ s/#//" \
	-e "/#AccountingStorageType=/ s/#//" \
        -e "/^[#]*AccountingStorageHost=/ c\AccountingStorageHost=${ctladdr}\\ " \
        -e "/^[#]*Acco.*StorageLoc=/ c\AccountingStorageLoc=\/var\/lib\/mysql\\ " \
        -e "/^[#]*Acco.*StoragePass=/ c\AccountingStoragePass=\/var\/run\/munge\/munge.socket.2\\ " \
        -e "/AccountingStoragePass=/ a\AccountingStoragePort=3306" \
        -e "/^[#]AccountingStorageUser=/ c\AccountingStorageUser=slurm\\ " \
        -e "/AccountingStorageUser=/ a\AccountingStoreJobComment=YES\\
AccountingStorageEnforce=associations" \
	$slurmConf
#        -e "/AccountingStorageUser=/ a\AccountingStoreJobComment=YES\\
#AccountingStorageEnforce=associations\\
#AccountingStorageTRES=gres/gpu,gres/gpu:gtx1080ti" \

sudo chown root: $slurmConf $slurmConf.backup

echo ""
echo "Restarting slurmctld daemon..."
sudo systemctl restart slurmctld

# Setup slurmdbd.conf
slurmdbConf="slurmdbd.conf"
sudo cp $slurmdbConf.example $slurmdbConf

sudo chown $USER: $slurmdbConf

sudo sed -i -e "/DbdAddr=/ s/localhost/${ctladdr}/" \
	-e "/DbdHost=/ s/localhost/${ctlname}/" \
        -e "/DbdHost=/ a\#DbdBackupHost=" \
	-e "/LogFile=/ s/\/slurm//" \
	-e "/PidFile=/ s/run/run\/slurm-llnl/" \
	-e "/^[#]*StorageHost=/ c\StorageHost=${ctlname}\\ " \
	-e "/^[#]Storageport=/ c\Storageport=3306\\ " \
	-e "/StoragePass=/ s/password/some_pass/" \
	-e "/#StorageLoc=/ s/#//" \
	$slurmdbConf

echo "yup"

sudo echo "PurgeEventAfter=12months" >> slurmdbd.conf
sudo echo "PurgeJobAfter=12months" >> slurmdbd.conf
sudo echo "PurgeResvAfter=2months" >> slurmdbd.conf
sudo echo "PurgeStepAfter=2months" >> slurmdbd.conf
sudo echo "PurgeSuspendAfter=1month" >> slurmdbd.conf
sudo echo "PurgeTXNAfter=12months" >> slurmdbd.conf
sudo echo "PurgeUsageAfter=12months" >> slurmdbd.conf

sudo chown root: $slurmdbConf

sudo scontrol reconfigure

# Edit mariadb config file
mdbConf=/etc/mysql/my.cnf
sudo chown $USER: $mdbConf

sudo echo "" >> ${mdbConf}
sudo echo "[mysqld]" >> ${mdbConf}
sudo echo "skip-networking=0" >> ${mdbConf}
sudo echo "skip-bind-address" >> ${mdbConf}

# Start database setup
echo ""
echo "Attempting to start MariaDB..."
sudo systemctl start mariadb || echo "WARNING: MariaDB had issues starting: troubleshoot and/or reboot the node!"

echo ""
echo "Configure the database manually before attempting to start slurmdbd."
echo "Refer to the SysAdmin Guide for manual database configuration"
