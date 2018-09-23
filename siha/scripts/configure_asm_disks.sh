
cat > /etc/udev/rules.d/99-oracle-asmdevices.rules <<EOF
KERNEL=="sde1",SYMLINK+="asmdisks/DATA",OWNER="oracle",GROUP="asmadmin",MODE="0660"
KERNEL=="sdf1",SYMLINK+="asmdisks/FRA",OWNER="oracle",GROUP="asmadmin",MODE="0660" 
KERNEL=="sdg1",SYMLINK+="asmdisks/CTLLOG1",OWNER="oracle",GROUP="asmadmin",MODE="0660"
KERNEL=="sdh1",SYMLINK+="asmdisks/CTLLOG2",OWNER="oracle",GROUP="asmadmin",MODE="0660" 
EOF

/sbin/udevadm control --reload-rules

echo "******************************************************************************"
echo "Prepare data disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s -a optimal /dev/sde mklabel gpt -- mkpart primary ext4 1MiB -2048s

/home/oracle/scripts/create_asm_disk.sh /dev/sde DATA

echo "******************************************************************************"
echo "Prepare fra disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s -a optimal /dev/sdf mklabel gpt -- mkpart primary ext4 1MiB -2048s

/home/oracle/scripts/create_asm_disk.sh /dev/sdf FRA

echo "******************************************************************************"
echo "Prepare ctllog1 disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s -a optimal /dev/sdg mklabel gpt -- mkpart primary ext4 1MiB -2048s

/home/oracle/scripts/create_asm_disk.sh /dev/sdg CTLLOG1


echo "******************************************************************************"
echo "Prepare ctllog2 disk." `date`
echo "******************************************************************************"
# New partition for the whole disk.
parted -s -a optimal /dev/sdh mklabel gpt -- mkpart primary ext4 1MiB -2048s

/home/oracle/scripts/create_asm_disk.sh /dev/sdh CTLLOG2
