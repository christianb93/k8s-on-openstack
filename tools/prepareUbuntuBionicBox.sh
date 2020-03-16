#!/bin/bash
#
# Get the latest Ubuntu Bionic Box and resize it
#

#
# First make sure that we have the latest box
# and remove older boxes
#
vagrant box add generic/ubuntu1804 --provider=libvirt --force
vagrant box prune --name "generic/ubuntu1804"


#
# Now do the actual resize. First we navigate to the
# directory where all the boxes are located
#
cd ~/.vagrant.d/boxes/generic-VAGRANTSLASH-ubuntu1804/
#
# Each box is in its own subdirectoy.
#
dirs=$(find . -maxdepth 1 -mindepth 1 -type d)
for x in $dirs; do
  if [ -x $x/libvirt ]; then
    echo "Resizing libvirt image in $x"
    # Each box contains an image in QCOW2 format
    qemu-img resize $x/libvirt/box.img 60G
    # Make a copy
    cp $x/libvirt/box.img $x/libvirt/box_orig.img
    # and expand the file system
    virt-resize -expand /dev/sda3 $x/libvirt/box_orig.img $x/libvirt/box.img 
  fi
done
