#/bin/sh
################################################################
# Usage : create_asm_disk.sh DEVICE DISK_NAME                  #
#         assumes partition created already                    #
################################################################

DEVICE=$1
DISK_NAME=$2
#GRID_HOME=/u01/app/grid/18.3.0.0.0_4.0
#ORACLE_HOME=$GRID_HOME
#ORACLE_BASE=/u01/app/oracle
#PATH=$ORACLE_HOME/bin:$PATH
#LD_LIBARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH

#export ORACLE_HOME PATH ORACLE_BASE
#ASMCMD=$GRID_HOME/bin/asmcmd

#partprobe "$DEVICE"

#$ASMCMD afd_label "${DISK_NAME}" "${DEVICE}1" --init
oracleasm createdisk ${DISK_NAME} ${DEVICE}1