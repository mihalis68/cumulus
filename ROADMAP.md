# Roadmap

This is an experiment project aimed at supplementing chef-bcpc with an
optional Cumulus VX based leaf/spine L3 (virtual) network. CURRENTLY
THIS PROJECT ACTUALLY DOES ABSOLUTELY NOTHING USEFUL.

Currently chef-bcpc when built on VMs uses the virtual ethernet switch
built into VirtualBox and assumes layer 2 spanning between all nodes
on each of the cluster networks. Similarly, L2 spanning is currently
required on real chef-bcpc clusters even when scaled to multiple racks
(as documemted in
https://github.com/bloomberg/chef-bcpc/blob/master/docs/network-arch-v1.md)

On the roadmap for chef-bcpc is a move to a pure L3 design using BGP
between racks. As a possible testing and development aid, being able
to simulate both the servers AND a pure L3 network environment all on
VirtualBox might be helpful.

Approximate roadmap for this is :

# practice configuring cumulus in vmware from script (bridged n/w)

# integrate DHCP of cumulus VMs with bcpc bootstrap node (hostonly
  n/w)

# convert cumulus VM configurations to support bcpc networks

# move bcpc VMs to single virtual leaf switch (still L2 spanned)

# when bcpc supports pure L3, distribute nodes across multiple leaves
  (pure L3)