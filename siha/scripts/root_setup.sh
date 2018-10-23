#!/bin/bash

updateOS(){
# Prepare yum with the latest repos.
echo "##############################################################################"
echo "update yum config and install packages"
echo "###############################################################################"

yum -y install yum-utils zip unzip
yum -y update
# 18c prereq works on rhel like distros
yum -y localinstall http://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-18c-1.0-1.el7.x86_64.rpm
yum -y localinstall /vagrant/software/oracle-database-xe-18c-1.0-1.x86_64.rpm

}

addGroups(){
echo "*****************************************************************************"
echo "Group setup " `date`
echo "******************************************************************************"

groupadd -g 54331 asmadmin
groupadd -g 54332 asmdba
groupadd -g 54333 asmoper
usermod -a -G asmadmin oracle
usermod -a -G asmdba oracle
usermod -a -G asmoper oracle

}

setupFileSystems(){

echo "******************************************************************************"
echo "Prepare /u01 disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s /dev/sdb mklabel gpt -- mkpart primary ext4 1MiB -0

# Add file system.
mkfs -t ext4 /dev/sdb1

# Mount it.
#UUID=$(blkid -o value /dev/sdb1 | grep -v xfs)
UUID=$(blkid  /dev/sdb1 | awk ' {print $2} '| awk -F'"' ' {print $2} ')
mkdir /u01
cat >> /etc/fstab <<EOF
UUID=${UUID}    /u01    ext4    defaults 1 2
EOF
mount /u01

echo "******************************************************************************"
echo "Prepare /u01/app/oraInventory disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s /dev/sdc mklabel gpt -- mkpart primary ext4 1MiB -0

# Add file system.
mkfs -t ext4 /dev/sdc1

# Mount it.
#UUID=$(blkid -o value /dev/sdb1 | grep -v xfs)
UUID=$(blkid  /dev/sdc1 | awk ' {print $2} '| awk -F'"' ' {print $2} ')
mkdir -p /u01/app/oraInventory
cat >> /etc/fstab <<EOF
UUID=${UUID}    /u01/app/oraInventory    ext4    defaults 1 2
EOF
mount /u01/app/oraInventory

echo "******************************************************************************"
echo "Prepare /u01/app/oracle/diag disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s /dev/sdd mklabel gpt -- mkpart primary ext4 1MiB -0

# Add file system.
mkfs -t ext4 /dev/sdd1

# Mount it.
#UUID=$(blkid -o value /dev/sdb1 | grep -v xfs)
UUID=$(blkid  /dev/sdd1 | awk ' {print $2} '| awk -F'"' ' {print $2} ')
mkdir -p /u01/app/oracle/diag
cat >> /etc/fstab <<EOF
UUID=${UUID}    /u01/app/oracle/diag    ext4    defaults 1 2
EOF
mount /u01/app/oracle/diag

}


deploySoftwareImages(){
echo "################################################################################"
echo "copying scripts " ` date `                         
echo "################################################################################"

mkdir -p ${GRID_HOME}
mkdir -p ${SCRIPTS_DIR}
mkdir -p ${SOFTWARE_DIR}
#mkdir -p ${DATA_DIR}
chown -R oracle:oinstall ${SCRIPTS_DIR} /u01 ${SOFTWARE_DIR} 

# Copy the scripts from the vagrant directory and run it.
cp -f /vagrant/scripts/* ${SCRIPTS_DIR}
cp -f /vagrant/software/* ${SOFTWARE_DIR}
chmod +x ${SCRIPTS_DIR}/*.sh

cp -f /vagrant/software/${GRID_IMAGE} ${GRID_HOME}
chown oracle:oinstall ${GRID_HOME}

}

extractHome(){
echo "################################################################################"
echo "Extracting Software for grid " ` date `                         
echo "################################################################################"

cd ${GRID_HOME}
su -p oracle -c "unzip ${GRID_IMAGE}"

}


installASMSupport(){
# Prepare environment and install the software.
echo "################################################################################"
echo "Configure ASM Support " ` date `                         
echo "################################################################################"
yum localinstall -y ${GRID_HOME}/cv/rpm/cvuqdisk-1.0.10-1.rpm

yum -y install kmod-oracleasm
yum -y localinstall http://download.oracle.com/otn_software/asmlib/oracleasmlib-2.0.12-1.el7.x86_64.rpm 
yum -y localinstall https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracleasm-support-2.1.11-2.el7.x86_64.rpm


cat >  /etc/sysconfig/oracleasm-_dev_oracleasm <<EOF
ORACLEASM_ENABLED=true
ORACLEASM_UID=oracle
ORACLEASM_GID=asmadmin
ORACLEASM_SCANBOOT=true
ORACLEASM_SCANORDER="sd"
ORACLEASM_SCANEXCLUDE=""
ORACLEASM_SCAN_DIRECTORIES=""
ORACLEASM_USE_LOGICAL_BLOCK_SIZE="false"
EOF

oracleasm init

}

addASMDisks(){
# ${GRID_HOME}/bin/asmcmd afd_configure -e
${SCRIPTS_DIR}/configure_asm_disks.sh 
}


printStorageConfig(){
echo "################################################################################"
echo "Storage Configured " ` date `                         
echo "################################################################################"
oracleasm-discover
oracleasm listdisks
}



setupGIHome(){
echo "################################################################################"
echo "Running Setup " ` date `                         
echo "################################################################################"


# ignore preReqs for swap size=RAM but need to check. 

su - oracle -c "${GRID_HOME}/gridSetup.sh -silent -ignorePrereqFailure -responseFile ${SOFTWARE_DIR}/siha.rsp"

}


setupInventory(){
echo "################################################################################"
echo "Creating Inventory " ` date `                         
echo "################################################################################"
# Run root scripts.
sh ${ORA_INVENTORY}/orainstRoot.sh
}

runRootScript(){
echo "################################################################################"
echo "Running root script " ` date `                         
echo "################################################################################"
# Run root scripts.

sh ${GRID_HOME}/root.sh
}


configureGIHome(){
echo "################################################################################"
echo "Running configuration tools  " ` date `                         
echo "################################################################################"
# run config tools
su -p oracle -c "${GRID_HOME}/gridSetup.sh -executeConfigTools -responseFile ${SOFTWARE_DIR}/siha.rsp -silent"

}

echo "################################################################################"
echo "setting environment " ` date `                         
echo "################################################################################"

export ORACLE_BASE=/u01/app/oracle
export GRID_HOME=/u01/app/grid/18.3.0.0.0_4.0
export GRID_IMAGE=LINUX.X64_180000_grid_home.zip
export ORACLE_HOME=$GRID_HOME
export SOFTWARE_DIR=/u01/app/oracle/software
export ORA_INVENTORY=/u01/app/oraInventory
export SCRIPTS_DIR=/home/oracle/scripts

updateOS
if [[ $? -ne 0 ]]; then 
  echo "Failed to update O/S Packages correctly"
  exit 1
fi

addGroups
if [[ $? -ne 0 ]]; then 
  echo "Failed to add necessary groups"
  exit 1
fi

setupFileSystems
if [[ $? -ne 0 ]]; then 
  echo "Failed to create necessary filesystem storage"
  exit 1
fi

#deploySoftwareImages
#if [[ $? -ne 0 ]]; then 
#  echo "Failed to copy necessary files"
#  exit 1
#fi

#extractHome
#if [[ $? -ne 0 ]]; then 
#  echo "Failed to extract Gold Image"
#  exit 1
#fi

#installASMSupport
#if [[ $? -ne 0 ]]; then 
#  echo "Failed to add packages necessary for ASM"
#  exit 1
#fi

#addASMDisks
#if [[ $? -ne 0 ]]; then 
#  echo "Failed to create ASM disks"
#  exit 1
#fi

#printStorageConfig

#setupGIHome
#TODO Handle Error codes from gridSetup.sh - 6 is optional prereqs failed. 
#ret=$?
#if [[ $ret -ne 0 ]]; then 
#  echo "Warning: gridSetup.sh failed to setup the GI Home"
#  echo "Error was : $ret "
#  #exit 1
#fi

#setupInventory
#if [[ $? -ne 0 ]]; then 
#  echo "Failed to create inventory"
#  exit 1
#fi

#runRootScript
#if [[ $? -ne 0 ]]; then 
#  echo "Root Script execution failed"
#  exit 1
#fi

#configureGIHome
#if [[ $? -ne 0 ]]; then 
#  echo "configuration tools failed"
#  exit 1
#fi
