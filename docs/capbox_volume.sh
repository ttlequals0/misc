cat /sys/block/sda/queue/optimal_io_size
cat /sys/block/sda/queue/minimum_io_size
cat /sys/block/sda/alignment_offset
cat /sys/block/sda/queue/physical_block_size
#Add optimal_io_size to alignment_offset and divide the result
# by physical_block_size. In my case this was (1048576 + 0) / 512 = 2048.
mkpart primary 4096s 100%


sudo parted -a optimal /dev/sda
mklabel gpt 
mkpart primary 4096s 100%
set 1 lvm on
print
quit

sudo pvcreate /dev/sda1
sudo vgcreate vg_captures /dev/sda1
sudo lvcreate -l 100%FREE -n lv_captures vg_captures
sudo mkfs.xfs  /dev/vg_captures/lv_captures
sudo mkdir -p /var/captures
echo "/dev/vg_captures/lv_captures   /var/captures  xfs    defaults,rw,_netdev    1 2" | sudo tee -a /etc/fstab
sudo mount -a






