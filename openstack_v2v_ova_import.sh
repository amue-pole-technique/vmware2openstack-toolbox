#!/bin/bash
# import dans openstack de serveur en provenance de VMware
# a partir de fichiers d'exports ova ou ovf
#
# auteurs : 
# alexandre.heitz@amue.fr
# houcem.yahya@ext.amue.fr  (calculs de selection des flavors)
#
SCRIPT_VERSION=2024-03-11


SCRIPT_DIR=$( dirname $0)
SCRIPT_CMD_LINE="$@"

# Ova file
OVA_FILE=""
OVA_TYPE=""
OVA_V2V_PATH=""

# temp directory
TMP_DIR=/data/tmp

# current server name running virt-v2v
THIS_VM_OPENSTACK_NAME=$( hostname -s )

# minimum ram requirement in Kb for virt-v2v
THIS_VM_VIRTV2V_RAM_MIN_KB=3500000

# script to source for cleaning the system of the imported VM
SCRIPT_CLEANUP_INCLUDE=$SCRIPT_DIR/openstack_v2v_ova_import_cleanup_common.include

# force a specific flavor on the new VM
VM_OS_FLAVOR_FORCE=0
VM_OS_FLAVOR_NAME=""
VM_OS_FLAVOR_MISSING=0

# existing target network receiving the imported VM
VM_OS_NETWORK=net-migration

# security groups to apply to the new VM
VM_OS_SECURITY_GROUP=""
VM_OS_SECURITY_GROUP_DEFAULT="intra_default_amue"

# steps possible to skip
IMPORT_SKIP_V2V=0
IMPORT_SKIP_CLEANUP=0
IMPORT_SKIP_VM_CREATION=0


_showUsage() {
    echo -e "
Syntaxe : $( basename $0 ) --guest <path/to/ova/or/ovf>
                [--skip_v2v-import] [--skip_sys_cleanup] [--skip_vm_creation]
                [--os-flavor-force <flavor>] [--os-network <network>] [--os-secgroup <sec group>]
                [--os-this-vm-name <vm migration> ] [--tmp </path/to/work/dir>]


  --guest </path/to/export> : Requis, chemin complet vers un fichier .ova (archive unique) ou .ovf (multi fichiers)
  
  --skip_v2v-import         : Ignore l'etape d'import pour commencer sur le nettoyage puis la creation de la vm. 
                              Utile en cas d'import reussi des volumes mais en erreur sur la VM cote openstack.
                              
  --skip_sys_cleanup        : Ignore l'etape de nettoyage du systeme importe (linux uniquement). 
                              Dependant d'avoir le FS systeme contenu sur un disque unique, parfois non fonctionnel
                              
  --skip_vm_creation        : Ignore l'etape de creation de la VM et l'application des security groups
  
  --os-flavor-force <flavor>: Desactive la selection automatique pour imposer le flavor/gabarit indique.
 
  --os-network <network>    : Reseau openstack cible recevant la VM (defaut: $VM_OS_NETWORK)
  
  --os-secgroup <sec group> : Nom des security groups a ajouter a la VM (defaut: ${VM_OS_SECURITY_GROUP_DEFAULT})
                              Repeter plusieurs fois pour ajouter plusieurs security groups.
  
  --os-this-vm-name <nom vm>: Nom de ce serveur de migration dans openstack (defaut: $THIS_VM_OPENSTACK_NAME )
  
  --tmp </path/to/work>     : Repertoire de travail de 5 a 10 Go d'espace libre (defaut: $TMP_DIR)
  
Notes : 
* Eviter les espaces dans les noms des objets openstack ou utiliser des ''.
* Les parametres --skip_* sont combinables
* Ce script ne s'occupe pas des logs, utiliser '| tee' si necessaire.
"
}

# Traitement de la ligne de commande -------------------------------------------

# verify the number of parameters
if [ $# -eq 0 ]; then _showUsage; exit 1; fi

while [ $# -gt 0 ]; do
    arg="$1"
    # handle both -param & --param syntax
    if echo "$arg" | egrep -q '^--[a-z]+'; then arg="${arg:1}"; fi

    case $arg in
        -help)
            _showUsage
            exit 1
            ;;

        -guest)
            OVA_FILE="$2"
            shift
            ;;

        -tmp|-temp|-tmp-dir)
            TMP_DIR=$2
            shift
            ;;

        -skip_v2v-import)
            IMPORT_SKIP_V2V=1
            ;;

        -skip_cleanup|-skip_sys_cleanup)
            IMPORT_SKIP_CLEANUP=1
            ;;

        -skip_vm_creation)
            IMPORT_SKIP_VM_CREATION=1
            ;;
        
        -os-flavor-force)
            VM_OS_FLAVOR_FORCE=1
            VM_OS_FLAVOR_NAME="$2"
            shift
            ;;
        
        -os-network)
            VM_OS_NETWORK="$2"
            shift
            ;;

        -os-secgroup)
            VM_OS_SECURITY_GROUP="${VM_OS_SECURITY_GROUP} --security-group $2"
            shift
            ;;
            
        -os-this-vm-name)
            THIS_VM_OPENSTACK_NAME="$2"
            shift
            ;;

        -version)
            echo "Version: $SCRIPT_VERSION"
            exit 0
            ;;

        # unknown
        *)
            echo "Unknown argument : $arg"
            _showUsage
            exit 1
            ;;
        esac

    #  next arg
    [ $# -gt 0 ] && shift
done

# parameters validation
if [ $UID -ne 0 ]; then echo "root or sudo required"; exit 1; fi

if [ -z "$OVA_FILE" ]; then echo "Error: the .ova / ovf file is mandatory"; exit 1; fi
if [ ! -e "$OVA_FILE" ]; then echo "Error: the .ova / ovf file was not found or is not readable"; exit 1; fi

# memory is in Kb - 4 Gb total minimum is required for virt-v2v
THIS_MEM_KB=$( grep -i "memtotal" /proc/meminfo | rev | cut -d ' ' -f2 |rev )
if [ $THIS_MEM_KB -lt $THIS_VM_VIRTV2V_RAM_MIN_KB ]; then echo "Error: at least $(( $THIS_VM_VIRTV2V_RAM_MIN_KB /1024 )) Kb in memory are required to execute virt-v2v"; exit 1; fi

if ! command -v openstack &>/dev/null; then echo "Error: the 'openstack' cli command was not found in the path"; exit 1; fi
if [ -z "$OS_AUTH_URL" ]; then echo "Error: the Openstack auth informations are missing in the environment"; exit 1; fi

sRet=$( openstack project list 2>&1 )
if [ $? -ne 0 ]; then echo "Error: could not access the openstack API. Check your auth token"; echo "$sRet"; exit 1; fi
if ! openstack server show "$THIS_VM_OPENSTACK_NAME"  &>/dev/null; then echo "Error: the migration server was not found in Openstack under the name: $THIS_VM_OPENSTACK_NAME"; exit 1; fi


OVA_NAME=$( basename "$OVA_FILE" 2>&1| rev | cut -d '.' -f2- | rev )
OVA_TYPE=$( basename "$OVA_FILE" 2>&1| rev | cut -d '.' -f1  | rev | tr '[:upper:]' '[:lower:]' )

if [ -z "${VM_OS_SECURITY_GROUP}" ]; then VM_OS_SECURITY_GROUP="--security-group ${VM_OS_SECURITY_GROUP_DEFAULT}"; fi


if [ ! -d "$TMP_DIR" ]; then mkdir -p "$TMP_DIR" || exit 1; fi
WORKDIR="$TMP_DIR/$OVA_NAME"

# temp workdir for virt-v2v - export is required
# not reusing "wordir" as virt-v2v will not care for its own existing files
export LIBGUESTFS_CACHEDIR="$TMP_DIR"
export TMP_DIR


# main -------------------------------------------------------------------------
echo "Import parameters : $SCRIPT_CMD_LINE"
echo "OVA File: $OVA_FILE"
echo "Type    : $OVA_TYPE"
echo "Workdir : $WORKDIR"
echo "start time: $(date '+%Y%m%d-%H%M%S')"
echo ""

mkdir -p $WORKDIR

if [ "$OVA_TYPE" == "ova" ]; then
    echo "Extracting the ovf descriptor from the OVA file ..."
    echo "Notice: ignore any tar error about 0 size block"
    
    # an ova file is a renamed tar file (or tar.gz) 
    tar xvf "$OVA_FILE" --wildcards --no-anchored --directory "$WORKDIR/"  '*.ovf'	|| exit 1

else
    echo "Copying the ovf descriptor in the workdir ..."
    cp -a "$OVA_FILE"  "$WORKDIR/"  || exit 1
fi

# Extracting the ovf informations ----------------------------------------------

echo "Retrieving the VM informations from the ovf descriptor ..."
# sometimes the OVA name is not the same as the ovf contained in the file
OVF_NAME=$( basename `ls -1 $WORKDIR/*.ovf` |head -1)
OVF_GUESTID=$( echo $OVF_NAME |cut -d '.' -f1 )

# retrieve base information from the ovf file
VM_NAME=$( grep -i "VirtualSystem ovf:id=" "$WORKDIR/$OVF_NAME"  | cut -d "=" -f2 | tr -d '"' | tr -d ">" )

if [ -z "$VM_NAME" ]; then echo "Error: couldn't find 'VirtualSystem ovf:id' in $WORKDIR/$OVF_NAME"; exit 1; fi

VM_SYSTEM=linux
if grep -i -q ":osType=.*win.*" "$WORKDIR/$OVF_NAME" || grep -i -q "<Description>.*Windows.*</Description>" "$WORKDIR/$OVF_NAME"; then VM_SYSTEM=windows; fi

# retrieve CPU and Memory usage
if [ $VM_OS_FLAVOR_FORCE -eq 0 ]; then
    x=$( grep VirtualQuantity $WORKDIR/$OVF_NAME | cut -d ">" -f2 | sed 's/[^0-9]*//g' |head -n1 )
    echo "CPU detected: $x"
    logresultx=$( echo "l($x)/l(2)" | bc -l )
    roundresultx=$( echo "($logresultx+0.5)/1" | bc )
    cpu=$( echo "2^$roundresultx" | bc -l )
    echo "CPU rounded: $cpu"
    y=$( grep VirtualQuantity $WORKDIR/$OVF_NAME | cut -d ">" -f2 | sed 's/[^0-9]*//g' |tail -n1 )
    echo "RAM detected: $y"
    logresulty=$( echo "l($y)/l(2)" | bc -l )
    roundresulty=$( echo "($logresulty+0.5)/1" | bc )
    ram=$( echo "2^$roundresulty" | bc -l )
    echo "Ram rounded: $ram"
    if [ -z "$cpu" ] || [ -z "$ram" ]; then echo "Error: cpu or ram is empty or could not be retrieved"; exit 1; fi


    VM_OS_FLAVOR_NAME=$(openstack flavor list -f yaml | grep "RAM: $ram" -A1 -B5 |grep "VCPUs: $cpu" -B6 |grep Name |cut -d":" -f2 |tr -d ' ' |head -1)
    echo "Openstack selected flavor: $VM_OS_FLAVOR_NAME"
    if [ -z "$VM_OS_FLAVOR_NAME" ]; then
        echo "WARNING: no corresponding flavor for the given CPU & RAM values could be selected"
        if [ $IMPORT_SKIP_VM_CREATION -eq 0 ]; then
            echo ""
            echo "WARNING: DUE TO THE NON-EXISTANT FLAVOR THIS SCRIPT WILL HALT ON THE VM CREATION (after the drive import and cleanup)"
            VM_OS_FLAVOR_MISSING=1
        fi
    fi

else
    echo "Openstack FORCED flavor: $VM_OS_FLAVOR_NAME"
    if ! openstack flavor show $VM_OS_FLAVOR_NAME &>/dev/null; then echo "Error: the forced flavor does not exist in Openstack"; exit 1; fi
fi


# Start the volumes import -----------------------------------------------------

echo ""
echo "Importing the vm drives into openstack ..."

# some controls
if openstack server show "$VM_NAME"  &>/dev/null; then echo "Error: the server $VM_NAME already exists in Openstack"; exit 1; fi
if [ $IMPORT_SKIP_VM_CREATION -eq 0 ] && ! openstack network show "${VM_OS_NETWORK}" &>/dev/null; then echo "Error: the network ${VM_OS_NETWORK} was not found"; exit 1; fi


if [ $IMPORT_SKIP_V2V -eq 0 ]; then
    # TODO: verify all drives and with the correct bus type
    if openstack volume show "${VM_NAME}-sda" &>/dev/null; then echo "Error: the volume ${VM_NAME}-sda already exists"; exit 1; fi
    
    # virt-v2v expect a directory for ovf files
    OVA_V2V_PATH="$OVA_FILE"
    if [ "$OVA_TYPE" == "ovf" ]; then OVA_V2V_PATH=$( dirname `readlink -f "$OVA_FILE"` ); fi
    
    echo "Notice 1: very slow start as virt-v2v will verify the file checksums - this cannot be skipped"
    echo "Notice 2: ignore any errors about: 'tar error and 0 size block' or 'read-only access mode flag'"
    virt-v2v -i ova "$OVA_V2V_PATH" -o openstack  -oo server-id="$THIS_VM_OPENSTACK_NAME"  -oo guest-id="$OVF_GUESTID"
    if [ $? -ne 0 ]; then exit 1; fi

    openstack volume set  $VM_NAME-sda --image-property hw_qemu_guest_agent=yes  --image-property hw_vif_multiqueue_enabled=true
    if [ "$VM_SYSTEM" == "linux" ]; then
        # notice: virt-v2v change the fstab to use /dev/vd?, setting these 2 properties after will present the drives as /dev/sd?
        openstack volume set  $VM_NAME-sda --image-property hw_disk_bus=scsi  --image-property hw_scsi_model=virtio-scsi
    fi

else
	echo "NOTICE: ==> virt-v2v drive import SKIPPED from command line"
fi


# load the script handling the cleanup of the system drive from the imported VM 
echo ""
echo "Openstack: attaching and cleaning up the system drive ..."
if [ $IMPORT_SKIP_CLEANUP -eq 0 ]; then
    if [ -s "$SCRIPT_CLEANUP_INCLUDE" ]; then
        source "$SCRIPT_CLEANUP_INCLUDE" || exit 1
    else
        echo "NOTICE: ==> the script '$SCRIPT_CLEANUP_INCLUDE' was not found - skipping"
    fi

else
	echo "NOTICE: ==> system drive cleanup SKIPPED from command line"
fi


# Create the VM + network + security groups ------------------------------------
echo ""
echo "Openstack: creating the server $VM_NAME with flavor '$VM_OS_FLAVOR_NAME' ..."
if [ $IMPORT_SKIP_VM_CREATION -eq 0 ]; then

    if [ $VM_OS_FLAVOR_MISSING -eq 1 ]; then echo "Error: no suitable flavor could be found on startup when retrieving the VM informations - aborting"; exit 1; fi

    echo "Command used: openstack server create --flavor $VM_OS_FLAVOR_NAME --nic net-id='${VM_OS_NETWORK}' --volume '${VM_NAME}-sda'  --wait '$VM_NAME'"
    VM_OS_CREATED=$( openstack server create --flavor $VM_OS_FLAVOR_NAME --nic net-id="${VM_OS_NETWORK}" --volume "${VM_NAME}-sda"  --wait "${VM_NAME}" 2>&1 )
    if [ $? -ne 0 ]; then echo "$VM_OS_CREATED"; exit 1; fi

    # retrieve the IP address of the imported server - only one should exist
    VM_OS_NETIP=$( echo "$VM_OS_CREATED" | grep -i "^| addresses *|" | cut -d '|' -f3 | cut -d '=' -f2 | tr -d ' ' )
    VM_OS_ID=$( echo "$VM_OS_CREATED" | grep -i "^| id *|" | cut -d '|' -f3 | tr -d ' ' )

    echo ""
    for i in $( openstack volume list --status available  -f yaml |grep -i "Name:" | egrep "${VM_NAME}\-sd[b-z]" |cut -d ":" -f2 | sort ); do
        echo "Openstack: server $VM_NAME - attaching volume $i ..."
        openstack server add volume "$VM_NAME"  "$i"
    done

    # for maintenance purpose and cohabitation with terraform all the security groups must be directly on the network port and not on the VM
    echo ""
    echo "Openstack: server $VM_NAME - change port name and add the security groups ..."

    OS_PORTS_LIST=$( openstack port list --network ${VM_OS_NETWORK} --server "${VM_NAME}" -f value 2>&1 )
    if [ $? -ne 0 ] || [ -z "$OS_PORTS_LIST" ]; then echo "Error: unexpected result when retrieving the VM network port"; echo "$OS_PORT_LIST"; exit 1; fi

    VM_OS_NETIP_ID=$( echo "${OS_PORTS_LIST}" | grep --fixed-strings "'${VM_OS_NETIP}'" | grep -i "active" | cut -d ' ' -f1 )
    if [ $( echo "$VM_OS_NETIP_ID" | wc -l ) != "1" ]; then
        echo "WARNING: multiple ports found for the server IP $VM_OS_NETIP"
        echo "$VM_OS_NETIP_ID"
        echo "No action done - skipping"

    else
        # splitted in case of any error on the security groups
        openstack port set $VM_OS_NETIP_ID  --name "${VM_NAME}"
        openstack port set $VM_OS_NETIP_ID  ${VM_OS_SECURITY_GROUP}
        # no error control here - nearly finished and secgroups can be corrected manually
    fi

    echo "Server $VM_NAME created with the network address $VM_OS_NETIP"
    
else
	echo "NOTICE: ==> Openstack VM creation, port renaming and security groups SKIPPED from command line"
fi

echo ""
echo "End time: $(date '+%Y%m%d-%H%M%S')"
echo "Done."
