#!/bin/bash

#===================================================================================
#
#          FILE:  install_slurm.sh
#
#   DESCRIPTION:  Basic slurm installation for Ubuntu 18.04
#
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:  Eleanor Coyle, coyleej@protonmail.com
#       COMPANY:  Azimuth Corporation
#       VERSION:  1.0
#       CREATED:  2019-01-28
#      REVISION:  2019-05-20
#
#===================================================================================

echo "Installing slurm on node "$HOSTNAME

clustername="Marvel"
ctlname="magneto"
ctladdr="10.0.10.43"
backupname="nebula"
backupaddr="10.0.0.1"

sudo apt update
sudo apt install munge libmunge-dev libpam-slurm slurmd slurmdbd slurm-wlm-doc \
	cgroup-tools mariadb-common mariadb-server #mysql-common mysql-server

if [ ${ctlname} == $HOSTNAME ]; then
	ctlnode="Y"
	sudo apt install slurmctld slurm-wlm
fi

read -p "How many GPUs on this node? : " numGPUs
if [ ${numGPUs} != 0 ]; then
	read -p "GPU type? (1: gtx1080ti, 2: rtx2080ti, 3:quadP620, 4:none): " typeGPU

	if [ ${typeGPU} == 1 ]; then
		typeGPU="gtx1080ti"
	elif [ ${typeGPU} == 2 ]; then
		typeGPU="rtx2080ti"
	elif [ ${typeGPU} == 3 ]; then
		typeGPU="quadP640"
	else
		typeGPU=""
	fi
fi

#### Creating log files ####
# Control node
if [ ${ctlnode} == "Y" ]; then
	logDir=/var/log
	pidDir=/var/log/slurm-llnl
	spoolDir=/var/spool/slurmctld

	sudo mkdir $logDir $spoolDir
	sudo chown slurm: $logDir $spoolDir
	sudo chmod 755 $logDir $spoolDir

	logFile=$logDir/slurmctld.log
	if [ ! -e $logFile ]; then
		sudo touch $logFile
	fi
	sudo chown slurm: $logFile

	logFile=$logDir/slurm_jobacct.log
	sudo touch $logFile
	sudo chown slurm: $logFile

	logFile=$logDir/slurm_jobcomp.log
	sudo touch $logFile
	sudo chown slurm: $logFile

	pidFile=$pidDir/slurmctld.pid
	sudo touch $pidFile
	sudo chown slurm: $pidFile
fi

# Compute nodes
logDir=/var/log
pidDir=/var/log/slurm-llnl
spoolDir=/var/spool/slurm

logFile=$logDir/slurmd.log
sudo touch $logFile
sudo chown slurm: $logFile

pidFile=$pidDir/slurmd.pid
sudo touch $pidFile
sudo chown slurm: $pidFile

sudo mkdir -p $spoolDir/d
sudo mkdir $spoolDir/ctld
sudo chown slurm: $spoolDir $spoolDir/d $spoolDir/ctld

#### Config files ####
# Download example config files
cd /home/$USER/Downloads
wget https://github.com/SchedMD/slurm/archive/slurm-17-11-2-1.tar.gz 
tar -xzf slurm-17-11-2-1.tar.gz

sudo cp "./slurm-slurm-17-11-2-1/etc/"*".conf.example" "/etc/slurm-llnl/"

cd "/etc/slurm-llnl"

# Setup gres.conf
if [ ${numGPUs} != 0 ]; then
	sudo echo "Name=gpu Type="${typeGPU}" File=/dev/nvidia0" > gres.conf

	ii=1
	while [ $ii -lt ${numGPUs} ]
	do
		sudo echo "Name=gpu Type="${typeGPU}" File=/dev/nvidia"${ii} >> gres.conf
		ii=$(( $ii + 1 ))
	done
fi

# Setup cgroup.conf
cat "cgroup.conf.example" | sudo sed "s/ConstrainRAMSpace=no/ConstrainRAMSpace=yes/" > cgroup.conf

# Edit grub settings for cgroup
grubFile="/etc/default/grub"
sudo cp ${grubFile} ${grubFile}".backup"

grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub | grep "cgroup_enable=memory"
if [ $? != 0 ]; then
	sudo sed '/GRUB_CMDLINE_LINUX=/ s/\"/ cgroup_enable=memory\"/2' <${grubFile} >${grubFile}
fi

grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub | grep "swapaccount=1"
if [ $? != 0 ]; then
	sudo sed '/GRUB_CMDLINE_LINUX=/ s/\"/ swapaccount=1\"/2' <${grubFile} >${grubFile}
fi

# Setup slurm.conf
slurmConf="slurm.conf"
sudo chown $USER: $slurmConf.example

# Autofills Oryx Pro values if slurmd -C fails
node_info=$(slurmd -C | grep NodeName || echo "NodeName="$HOSTNAME" CPUs=12 Boards=1 SocketsPerBoard=1 CoresPerSocket=6 ThreadsPerCore=2 State=UNKNOWN")

sudo sed -e "/ClusterName=/ s/linux/${clustername}/" \
	-e "/ControlMachine=/ s/linux0/${ctlname}/" \
	-e "/^[#]*ControlAddr=/ c\ControlAddr=${ctladdr}\\ " \
	-e "/^[#]BackupController=/ c\BackupController=${backupname}\\ " \
	-e "/^[#]*BackupAddr=/ c\BackupAddr=${backupaddr}\\ " \
	-e "/SlurmctldPidFile=/ s/run/run\/slurm-llnl/" \
	-e "/SlurmdPidFile=/ s/run/run\/slurm-llnl/" \
	-e "/ProctrackType=/ s/pgid/cgroup/" \
	-e "/FirstJobId=/ a\RebootProgram=\"\/sbin\/reboot\"" \
	-e "/^[#]*Prop.*R.*L.*Except=/ s/#//" \
	-e "/Prop.*R.*L.*Except=/ s/=.*/=MEMLOCK/" \
	-e "/^[#]*TaskPlugin=/ c\TaskPlugin=task\/cgroup\\ " \
	-e "/InactiveLimit=/ s/=.*/=600/" \
	-e "/SchedulerType=/ a\DefMemPerNode=1000" \
	-e "/^[#]SelectType=/ c\SelectType=select/cons_res\\ " \
	-e "/SchedulerAuth=/ a\SelectTypeParameters=CR_CPU_Memory" \
	-e "/FastSchedule=/ a\EnforcePartLimits=YES" \
	-e "/COMPUTE NODES/ i\# RESOURCES\\
GresTypes=gpu\\
#" \
	-e "/^NodeName=linux.*Procs.*State.*/ s/NodeName.*/${node_info} Gres=gpu:${numGPUs} State=UNKNOWN/" \
	-e "/^PartitionName=/ s/ALL Default/ALL OverSubscribe=NO Default/" \
	<$slurmConf.example >$slurmConf

sudo chown root: $slurmConf.example $slurmConf

# Start slurm
echo "Initial slurm setup on $HOSTNAME finished.\nAttempting to start slurm..."

pidDir=/var/run/slurm-llnl
sudo chown slurm: $pidDir/slurmd.pid
sudo systemctl start slurmd

if [ ${ctlnode} == "Y" ]; then
	sudo chown slurm: $pidDir/slurmcltd.pid
	sudo systemctl start slurmctld
fi

# Leaving the tarball alone, removing the extracted folder
sudo rm -rf "/home/"$USER"/Downloads/slurm-slurm-17-11-2-1/"

echo "Manual start commands are sudo slurmd -Dvvvv and sudo slurmctld -Dvvvv"
echo "Slurm daemons are not enabled yet. Test slurm first."
echo "Any inter-machine communication must be set up manually!"
echo "This script does not perform any database setup."
