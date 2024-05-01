[TOC]

---
# Références

* ref: https://libguestfs.org/virt-v2v.1.html
* ref: https://github.com/libguestfs/virt-v2v

# prérequis
Un système linux plus que récent (debian 11, centos 9)
Attention, le choix de la distribution nécessite virt-v2v > v1.42.  
Au moment de la rédaction de ce document, d'après pkgs : https://pkgs.org/search/?q=virt-v2v  
seul debian SID disposait d'une version suffisante, le choix s'est donc porté vers debian 11.


Ce système doît être installé DANS L'ENVIRONNEMENT OPENSTACK CIBLE.  
l'outil virt-v2v effectue des manipulations Openstack qu'il attache à sa propre machine comme support.  
Il n'est donc pas possible d'importer une VM dans un projet openstack différent de celui ciblé.  
Alternative : une fois la VM cible importée, supprimer l'instance et transférer ses disques vers l'espace concerné.  
Alternative 2 : transférer entre les espaces openstack le disque système de la VM contenant virt-v2v.  

La machine de travail doit disposer de beaucoup de stockage : les exports VMware doivent être ramenés au format .ova ou directement en vmx+vmdk sur la machine de travail.  
Structure conseillée : disque système avec virt-v2v, un disque de travail (~3 à 10 Go) et un disque de stockage des OVA

---
# exports OVA et OVF
vSphere sait effectuer des exports en ovf et aussi ova.  
Cependant, suivant les versions (vSphere 6.5), l'option ova a disparu de l'interface.  

Elle reste disponible en cli avec les commandes:  

* Export-VApp via PowerCLI : `Export-VApp -vApp $myVApp -Destination "C:\vapps\" -Format Ova`  
alt: `Export-VApp -vApp $myVApp -Destination "C:\vapps\myVapp.ova" `  
[ref vmware](https://developer.vmware.com/docs/powercli/latest/vmware.vimautomation.core/commands/export-vapp/#ExportVApp)  
* export-vm: `connect-viserver <ESXi host>`, puis `export-vm -vm <VM Name> -format OVA -destination <Path>`


A défaut, il est possible de transformer un export ovf en ova. C'est en réalité un tar.gz, sans notion d'arborescence (même ./ doit être absent)
```
cd .../ovf/vm/
# aucun répertoire ne doit être présent
# ne pas utiliser . comme source, faisant usage du mode récursif.
tar czvf ../vm.ova *
```

---
# Installation de virt-v2v

Distribution de type Debian. 

## Prérequis systèmes

mise à jour du systeme
```
sudo apt-get update
sudo apt-get upgrade -y

# optionnel debian: clavier francais pour la console 
sudo apt-get install keyboard-configuration kbd
```

Modification interactive pendant installation, si l'interface n'apparait pas, utiliser :  
```
sudo dpkg-reconfigure keyboard-configuration
sudo service keyboard-setup restart 
```

## installer libguestfs et virt-v2v

Il est possible d'avoir plus de 400 packages à ramener.  
C'est lié à une dépendance bancale sur des drivers video.
```
sudo apt-get install -y libguestfs-tools sshfs

# ramener la dernière version hors repo de virt-v2v
# source: https://pkgs.org/search/?q=virt-v2v
cd /tmp
wget http://ftp.us.debian.org/debian/pool/main/v/virt-v2v/virt-v2v_1.44.0-1+b1_amd64.deb

# récupérer les prérequis du package.
dpkg --info virt-v2v_1.44.0-1+b1_amd64.deb |grep -i "depends:"

# ajuster "apt install" en fonction de la liste
sudo apt-get install -y libc6 libglib2.0-0 libguestfs0 libjansson4 libosinfo-1.0-0 libpcre2-8-0  libvirt0 libxml2

# installer le .deb
sudo dpkg -i virt-v2v_1.44.0-1+b1_amd64.deb
```

En cas d'erreur avec une dépendance absente, débloquer apt avec:  `sudo dpkg -r virt-v2v`  
Corriger, puis relancer l'installation.  

Si les dépendances ne peuvent être fournies, il reste l'option de ramener le dernier tag du repo github et compiler virt-v2v.  


## install openstackcli

En global dans le systeme pour virt-v2v qui a besoin de sudo/root
```
sudo apt-get install -y python3-dev python3-pip
sudo python3 -m pip install --system  python-openstackclient
```

## Windows - support (optionnel)

Pour traiter les serveurs Windows, virt-v2v nécessite 3 éléments :
* l'image iso des drivers virtio
* l'outil srvany.exe venant du ressource kit Server 2003
* l'outil pnp_wait.exe utilisé dans l'installation de drivers

un repo Redhat fournis une déclinaison compatbile à ces 2 derniers éléments, mais nécessitant d'être compilés.  
Etant pour du Windows, une fois générés ils sont réutilisables sans contrainte.  

### srvany+pnp_wait: prerequis et compilation
Ref: https://fedoraproject.org/wiki/MinGW
Alternative : le ressource kit de Win2000 (la version x64 est peut être disponible sur le Reskit de XP x64)

```
sudo apt-get install -y autoconf build-essential mingw-w64

mkdir /tmp/rhsrvany && cd /tmp/rhsrvany 
wget https://github.com/rwmjones/rhsrvany/archive/refs/heads/master.zip
unzip master.zip
cd rhsrvany-*

autoreconf -i
# build for x86 - use for x64: --host=x86_64-w64-mingw32
./configure --host=i686-w64-mingw32 
make

# optionnel - en cas de somnolence parce que trop long
if [ $? -ne 0 ]; then echo "ERROR"; fi
```

Les 2 fichiers exe sont disponibles, les positionner pour virt-v2v
```
sudo mkdir -p /usr/share/virt-tools
sudo cp pnp_wait/pnp_wait.exe  /usr/share/virt-tools/pnp_wait.exe
sudo cp RHSrvAny/rhsrvany.exe  /usr/share/virt-tools/rhsrvany.exe
```

### Drivers virtio
ref: https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/  
ref2: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/  => version stable non signée

Si possible, utiliser plutot la version fournie par redhat depuis un système RHEL disposant d'une licence active.  
Celle venant de fedora n'est pas signée pour le secure boot, pouvant poser problème.  

Installation pour la version Fedora.
```
sudo mkdir -p /usr/share/virtio-win
sudo wget --show-progress --output-document=/usr/share/virtio-win/virtio-win.iso  https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
```

Pour l'iso signée par Redhat, voir la documentation dédiée pour plus de détail (libguestfs - virt-v2v - Drivers virtio depuis Red Hat.md)  
Version rapide : depuis un serveur RHEL, lancer
```
sudo yum install virtio-win
```

Puis ramener le fichier iso sur le serveur de migration dans le même répertoire, même nom que pour Fedora.

