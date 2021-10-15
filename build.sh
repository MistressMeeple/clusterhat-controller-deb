#!/bin/bash
git commit -a -m init
#rm $(ls -I ".deb" /mnt/win/cluster-artifacts/)
rm /mnt/win/cluster-artifacts/clusterctrl*.orig.tar.gz
gbp buildpackage --git-ignore-new --git-export-dir=../cluster-artifacts --git-debian-branch=master --git-upstream-branch=master --git-upstream-tree=master
git clean -dfx
#sudo chroot /mnt/win/MNT /usr/bin/apt remove clusterctrl -y
cp /mnt/win/cluster-artifacts/clusterctrl_*.deb /mnt/win/MNT2/home/pi/clusterctrl.deb
#sudo chroot /mnt/win/MNT2 apt install /home/pi/clusterctrl.deb
