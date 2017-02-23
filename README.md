Overview
========

Experimental build of a Cumulus VX based virtual network aimed at
running https://github.com/bloomberg/chef-bcpc in a full (virtual)
leaf/spine setup.

Usage :

```
./leaf-spine.sh
```

add -v for verbose
add -f to force building even if the VMs exist


Currently this just recreates the example network shown on the Cumulus
Getting Started pages
https://docs.cumulusnetworks.com/display/VX/Creating+a+Two-Spine,+Two-Leaf+Topology

For a first experiment the management network on each VM is simply set
to bridged for easy access from the host. A more appropriate choice
will probably be hostonly or internal networking.