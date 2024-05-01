L'outil virt-v2v impose d'avoir de l'espace libre sur chaque filesystem de la VM à importer.  
Si un seul d'entre eux est utilisé à 100%, l'opération échoue sans contournement.  

Sont indiquées sur ce document la liste des actions et commandes  
pour monter un vmdk en écriture et le manipuler.


Note: pour les actions ci-après, s'il s'agit du répertoire /save_syst posant problème,  
il est généralement sous le disk3, volume explvg_?-sav*

```
# prérequis
apt-get install -y libguestfs-tools kpartx


# decompresser le fichier ova dans un espace de travail
cd /repertoire/avec/500Go/espace/libre/
mkdir tmp
cd tmp
tar xvf /dir/to/ova/files/vm.ova


# lister les FS présents dans un vmdk
virt-filesystems -a <vm_diskX>.vmdk  --all

# convertir en raw le fichier vmdk
qemu-img convert -f vmdk -O raw <VM_disk?>.vmdk disk_work.img

# Montage du disque via kpartx automatiquement sous /dev/mapper/loop0p?
kpartx -a -v disk_work.img

# s'il n'y a pas de LVM, récupérer la partition voulue 
# nommée loop0p? sous /dev/mapper/
lsblk
ls -l /dev/mapper/

# activer le vg s'il y avait une partition LVM
vgchange -a y /dev/<nom de vg>

# monter la partition
mount /dev/mapper/<vg_cible_lv_cible OU part_loop0p?>  /mnt

# faire du nettoyage
cd /mnt
rm <whatever>

# retirer la partition
umount /mnt

# désactiver le vg s'il y a lieu
vgchange -a n /dev/<nom de vg>


# retirer le montage de kpartx
cd /espace/de/stockage/tmp
kpartx -d -v disk_work.img

# remettre en vmdk le fichier raw
mv <VM_disk?>.vmdk  <VM_disk?>.vmdk_org
qemu-img convert -f raw -O vmdk disk_work.img  <VM_disk?>.vmdk 

# si ok, nettoyage
rm disk_work.img

# récupérer le sha256 et l'intégrer dans le manifeste de l'ova
sha256sum <VM_disk?>.vmdk 
cp -a <VM>.mf <VM>.mf_org
vi <VM>.mf
# remplacer par la valeur obtenue du sha pour le disque cible


# générer l'ova
# attention, aucune notion de chemin conservée dans l'archive. 
# OK => nomvm_disk0.vmdk
# KO => ./nomvm_disk0.vmdk
# Le "ls | sort | ..." est utilisé afin que le fichier .ovf soit en premier dans l'archive et ecarter les fichiers inutiles
GZIP=-1  tar czvf ../<VM>.ova $( ls -1 | sort -r |grep -v _org )

# terminé, pret a servir
```
