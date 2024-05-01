
Rechercher le disque désiré et vérifier le type de partition  
nb: fdisk assimile ntfs et exfat ensemble  
```
	lsblk
	sudo fdisk -l /dev/xxx
```

Puis vérifier le kernel
```
	uname -r
```    
exemple:  3.10.0-1062.9.1.el7.x86_64


Creer le repertoire de montage, ramener le driver si nécessaire, puis effectuer le mount
```
sudo mkdir /mnt/export-ova

# Si ce n'est pas un kernel 4+, installer le module ntfs-3g (repo Epel requis) puis monter la partition
	sudo yum install ntfs-3g rsync
	sudo mount -o ro -t ntfs-3g /dev/xxx1 /mnt/export-ova

# Si c'est un kernel 4, faire directement :
	sudo modprobe ntfs rsync
	sudo mount -t ntfs -o ro /dev/xxx1 /mnt/export-ova
```

Avec le driver ntfs-3g requis, il se peut que le système n'ait pas  EPEL actif.  
Et aussi indisponible dans les repos pré-établis de subscription-manager.  
Dans ce cas, l'installer depuis Fedora project et le désactiver une fois terminé avec.  
```
# Installer EPEL - attention, ici c'est pour RHEL7/Centos7
sudo yum install -y yum-utils
sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# effectuer l'installation du driver ntfs
sudo yum install ntfs-3g rsync

# recuperer le nom exact de EPEL
sudo yum repolist
# desactiver EPEL et vérifier
sudo yum-config-manager --disable epel
sudo yum repolist
```
