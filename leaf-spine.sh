#!/bin/bash

#
# Scripted version of the example leaf/spine setup given by Cumulus
# for learning Cumulus VX networking
#

VBM=/usr/local/bin/VBoxManage
CUMULUS_IMAGE=cumulus-linux-3.2.1-vx-amd64-1486153138.ac46c24zd00d13e.ova

while [[ -n "$1" ]]; do
    if [[ "$1" = "-f" ]]; then
	FORCE=true
    elif [[ "$1" = "-v" ]]; then
	VERBOSE=true
    else
	echo "Usage: $0 [-f] [-v] "
	echo "Unrecognized \"$1\""
	exit
    fi
    shift
done

if [[ ! -f $CUMULUS_IMAGE ]]; then
    echo "$0 : Error could not find ${CUMULUS_IMAGE}"

    echo "$0 : You have to obtain the Cumulus .ova file yourself by registering with Cumulus and accepting the licensing agreement."
    echo "$0 : Please see https://cumulusnetworks.com/products/cumulus-vx/"

    exit
fi

# conditional printf
function vftrace() {
    if [[ -n "$VERBOSE" ]]; then
        printf "$@"
    fi
}

function delvm_if_force() {
    EXISTS=""
    VMNAME="$1"
    MATCH=`$VBM list vms | grep "${VMNAME}"`
    if [[ -n "${MATCH}" ]]; then
	EXISTS=true
	if [[ -n "${FORCE}" ]]; then
	    vftrace "Deleting $VMNAME due to force ... "
	    $VBM unregistervm "${VMNAME}" --delete >/dev/null 2>&1
	    vftrace "done\n"
	    EXISTS=""
	fi
    else
	EXISTS=""
    fi
}

VM_PREFIX="Cumulus VX"
COMMON_OPTIONS="--vsys 0"


function check_vm_running() {
    RUNNING=""
    VMNAME="$1"
    RUN=`$VBM list runningvms | grep "${VMNAME}"`
    if [[ -n "${RUN}" ]]; then
	RUNNING=true
    fi
}

function startVM() {
    vftrace "startVM ${VMNAME}\n"
    VMNAME="$1"
    check_vm_running "${VMNAME}"
    if [[ -z "$RUNNING" ]]; then
	vftrace "Starting $VMNAME\n"
	$VBM startvm "${VMNAME}" --type gui
    else
	vftrace "$VMNAME was already running\n"	
    fi
}

function stopVM() {
    vftrace "stopVM ${VMNAME}\n"
    VMNAME="$1"
    check_vm_running "${VMNAME}"
    if [[ -n "$RUNNING" ]]; then
	vftrace "Stopping $VMNAME\n"
	$VBM controlvm "${VMNAME}" poweroff
    else
	vftrace "$VMNAME was already stopped\n"	
    fi
}

# management network type
MNET=bridged

function adjust_mgmt() {
    VMNAME=$1
    NIC=$2
    vftrace "adjust_mgmt $VMNAME $NIC\n"
    if [[ "${MNET}" = bridged ]]; then
	$VBM modifyvm "${VMNAME}" --nic1 bridged --bridgeadapter1 en0    >/dev/null 2>&1
    else
	$VBM modifyvm "${VMNAME}" --nic"${NIC}" hostonly                 >/dev/null 2>&1
	$VBM modifyvm "${VMNAME}" --hostonlyadapter"${NIC}" vboxnet0     >/dev/null 2>&1
    fi
}

MGMT_NIC_TYPE=

for LEAF in 1 2; do
    VMNAME="${VM_PREFIX}-leaf${LEAF}"

    stopVM "${VMNAME}"

    delvm_if_force "$VMNAME"

    if [[ -z "$EXISTS" ]]; then
	vftrace "Import $CUMULUS_IMAGE for $VMNAME ... "
	$VBM import $CUMULUS_IMAGE ${COMMON_OPTIONS} -vmname "${VMNAME}" >/dev/null 2>&1
	vftrace "done\n"
	vftrace "Modify NICs ... "       

	adjust_mgmt "${VMNAME}" 1

	$VBM modifyvm "${VMNAME}" --nic2 intnet --intnet l${LEAF}s1     >/dev/null 2>&1
	$VBM modifyvm "${VMNAME}" --nic2 intnet --intnet l${LEAF}s2     >/dev/null 2>&1
	$VBM modifyvm "${VMNAME}" --nic2 intnet --intnet leaf${LEAF}    >/dev/null 2>&1
	vftrace "done\n"
    else
	vftrace "${VMNAME} exists\n"
    fi
done

#set -x
for SPINE in 1 2; do

    VMNAME="${VM_PREFIX}-spine${SPINE}"

    stopVM "${VMNAME}"

    delvm_if_force "$VMNAME"

    if [[ -z "$EXISTS" ]]; then
	vftrace "Import $CUMULUS_IMAGE for $VMNAME ... "
	$VBM import $CUMULUS_IMAGE ${COMMON_OPTIONS} -vmname "${VMNAME}" >/dev/null 2>&1
	vftrace "done\n"
	vftrace "Modify NICs ... "       

	adjust_mgmt "${VMNAME}" 1

	$VBM modifyvm "${VMNAME}" --nic2 intnet --intnet l${SPINE}s1    >/dev/null 2>&1
	$VBM modifyvm "${VMNAME}" --nic2 intnet --intnet l${SPINE}s2    >/dev/null 2>&1
	$VBM modifyvm "${VMNAME}" --nic2 intnet --intnet spine${SPINE}  >/dev/null 2>&1
	vftrace "done\n"
    else
	vftrace "${VMNAME} exists\n"
    fi
done

function getvminfo {
    
    HOSTNAME="$1"

    # extract the first mac address for this VM
    MAC1=`$VBM showvminfo "$HOSTNAME" --machinereadable | grep macaddress1 | tr -d \" | tr = " " | awk '{print $2}'`
    # add the customary colons in
    MAC1=`echo $MAC1 | sed -e 's/^\([0-9A-Fa-f]\{2\}\)/\1_/'  \
        -e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
        -e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
        -e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
        -e 's/_\([0-9A-Fa-f]\{2\}\)/:\1_/' \
        -e 's/_\([0-9A-Fa-f]\{2\}\)/:\1/'`

    MAC1=`echo $MAC1 | sed -e 's/^0//' -e 's/:0/:/g'`
    
    IP=`arp -na | grep -i $MAC1 | awk '{print $2}' | tr -d \( | tr -d \)`
    echo $IP    
    if [[ -z "$IP" ]]; then
	$VBM showvminfo "$HOSTNAME" --machinereadable | grep macaddress1 | tr -d \" | tr = " " | awk '{print $2}' > "${HOSTNAME}fail.txt"
    fi
}

SOCKETDIR=${HOME}/.ssh/sockets
if [[ ! -d $SOCKETDIR ]]; then
    mkdir ${SOCKETDIR}
    chmod a+rwx ${SOCKETDIR}
else
    ls ${SOCKETDIR}
fi

SSH_COMMAND_OPTS="-o ControlMaster=auto -o ControlPath=${SOCKETDIR}/%r@%h-%p -o ControlPersist=600"
SSHCOMMON="-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o VerifyHostKeyDNS=no"
SSHCMD="ssh $SSH_COMMAND_OPTS ${SSHCOMMON}"
SCPCMD="scp $SSH_COMMAND_OPTS ${SSHCOMMON}"

declare -a ADDRS

# Work out the IP address of this VM and then install an ssh key to
# allow easy access from now on
function preconfig_vm() {
    VMNAME="$1"
    check_vm_running "$VMNAME"
    if [[ -n "$RUNNING" ]]; then
	vftrace "$VMNAME is running\n"
	IP=`getvminfo "${VMNAME}"`
	if [[ -z "$IP" ]]; then
	    echo "$VMNAME has no IP address!"
	else
	    vftrace "Now configuring ${VMNAME} ($IP) ..."
	    cat ~/.ssh/id_rsa.pub | sshpass -p 'CumulusLinux!' $SSHCMD cumulus@${IP} 'umask 0077; mkdir -p .ssh; cat >> .ssh/authorized_keys'
	    vftrace "Key copied\n"
	fi
    fi
    echo $IP
}

# Get the VMs started
for LEAF in 1 2; do
    VMNAME="${VM_PREFIX}-leaf${LEAF}"
    startVM "$VMNAME"
done
for SPINE in 1 2; do
    VMNAME="${VM_PREFIX}-spine${SPINE}"
    startVM "$VMNAME"
done

sleep 20
LOCALNET="10.0.1.0/24"
vftrace "Updating arp for $LOCALNET ..." 
nmap -sn $LOCALNET >/dev/null 2>&1
vftrace "done\n"


for LEAF in 1 2; do
    VMNAME="${VM_PREFIX}-leaf${LEAF}"
    preconfig_vm "${VMNAME}"
    if [[ -n "$IP" ]]; then
	ADDRS[$LEAF]="$IP"
	${SCPCMD} Quagga.conf.leaf${LEAF} interfaces.leaf${LEAF} daemons sudo cumulus@"${IP}":/tmp
	echo "CumulusLinux!" | ${SSHCMD} -t cumulus@${IP} "sudo -S cp /tmp/sudo /etc/sudoers.d/cumulus "
	${SSHCMD} -t cumulus@"${IP}" "sudo cp /tmp/interfaces.leaf${LEAF} /etc/network/interfaces"
	${SSHCMD} -t cumulus@"${IP}" "sudo cp /tmp/daemons /etc/quagga/daemons"
	${SSHCMD} -t cumulus@"${IP}" "sudo cp /tmp/Quagga.conf.leaf${LEAF} /etc/network/Quagga.conf"
	${SSHCMD} -t cumulus@"${IP}" "sudo systemctl restart networking"
	${SSHCMD} -t cumulus@"${IP}" "sudo systemctl restart quagga.service"
    else
	vftrace "Couldn't finish configuring $VMNAME\n"
	exit
    fi
done

for SPINE in 1 2; do
    VMNAME="${VM_PREFIX}-spine${SPINE}"
    preconfig_vm "${VMNAME}"
    if [[ -n "$IP" ]]; then
	ADDRS["$SPINE"+2]="$IP"
	${SCPCMD} Quagga.conf.spine${SPINE} interfaces.spine${SPINE} daemons sudo cumulus@"${IP}":/tmp
	echo "CumulusLinux!" | ${SSHCMD} -t cumulus@${IP} "sudo -S cp /tmp/sudo /etc/sudoers.d/cumulus "
	${SSHCMD} -t cumulus@"${IP}" "sudo cp /tmp/interfaces.spine${SPINE} /etc/network/interfaces"
	${SSHCMD} -t cumulus@"${IP}" "sudo cp /tmp/daemons /etc/quagga/daemons"
	${SSHCMD} -t cumulus@"${IP}" "sudo cp /tmp/Quagga.conf.spine${SPINE} /etc/network/Quagga.conf"
	${SSHCMD} -t cumulus@"${IP}" "sudo systemctl restart networking"
	${SSHCMD} -t cumulus@"${IP}" "sudo systemctl restart quagga.service"
    else
	vftrace "Couldn't finish configuring $VMNAME\n"
	exit
    fi
done

# run tests
IP1=${ADDRS[1]}
IP2=${ADDRS[2]}
IP3=${ADDRS[3]}
IP4=${ADDRS[4]}

vftrace "IPs $IP1 $IP2 $IP3 $IP4\n"
if [[ -z "$IP1" && -z "$IP2" && -z "$IP3" && -z "$IP4" ]]; then
    vftrace "Some VMs didn't get IP addresses, tests not attempted\n"
    exit
else
    vftrace "All VMs configured\n"
fi

vftrace "IPs : $IP1 $IP2 $IP3 $IP4\n"
${SSHCMD} -t cumulus@"${IP1}" "ping -c1 $IP2; ping -c1 $IP3; ping -c1 $IP4"
