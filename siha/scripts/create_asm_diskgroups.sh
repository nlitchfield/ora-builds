#!/bin/bash
ORACLE_SID=+ASM
source oraenv


$ORACLE_HOME/bin/asmca -silent -createDiskGroup -diskGroupName FRA -disk /dev/oracleasm/fra -redundancy EXTERNAL -au_size 1 -compatible.asm 12.1 -compatible.rdbms 12.1 -compatible.advm 12.1
$ORACLE_HOME/bin/asmca -silent -createDiskGroup -diskGroupName CTLLOG1 -disk /dev/oracleasm/ctllog1 -redundancy EXTERNAL -au_size 1 -compatible.asm 12.1 -compatible.rdbms 12.1 -compatible.advm 12.1
$ORACLE_HOME/bin/asmca -silent -createDiskGroup -diskGroupName CTLLOG2 -disk /dev/oracleasm/ctllog2 -redundancy EXTERNAL -au_size 1 -compatible.asm 12.1 -compatible.rdbms 12.1 -compatible.advm 12.1
