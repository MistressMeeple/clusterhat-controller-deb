# clusterhat-controller-deb
Build upon burtyb/clusterhat-image to create easy installable debian packages rather than relying on full os installs.
This supports ONLY clusterhat v2 as I have removed the functionality I did not need
A few commands have been tweaked, a few removed and a few added. All to suit my needs
The main change is the entire USBBOOT command structure that uses:
- VirtualFS, to limit the size of the node's OS 
- OverlayFS, to share one base install rather than having to keep 4 copies of the same os install
- NFS, same as it was before

TODO: 
- usbboot resize
- use git to set where files are located and renamed to, rather than copy paste. allowing for better upstream-pull and updating
- set usbboot-able os to download automatically
- 
- make usbboot debs?
