[TOC]

---

# Références

* ref: https://libguestfs.org/virt-v2v.1.html
* ref: https://github.com/libguestfs/virt-v2v

---
# Prérequis

Accès à l'api openstack de l'hébergeur requis, avec un token disposant de droits de création de volumes de stockage.  
L'exécution des commandes se fera depuis une VM de migration dans l'espace Openstack devant recevoir les exports de VM.  
Un disque dédié de grande taille monté sur /mnt/storage dans la VM de migration.  
Le ou les exports sous forme de fichiers ova ont été déposés dans la VM de migration, sous: `/mnt/storage/ova`  


---
# Conversion d'un export OVA

L'usage de root est requis, l'outil virt-v2v manipulant directement le système (montage de disques).
Dans le principe, virt-v2v va :

* monter localement chaque vmdk source
* créer un volume de stockage openstack
* l'associer au serveur de migration et le monter localement
* effectuer une copie par bloc de disque à disque

Ceci explique le niveau de droits requis, ainsi que le temps pris, virt-v2v parcourant la totalité de l'espace théorique de chaque disque.  


### Traitement
```
sudo su -

# charger le token de l'api openstack
source ...token...

# utilisation d'un stockage temporaire différent que /var/tmp
export LIBGUESTFS_CACHEDIR=/mnt/storage/tmp
mkdir -p $LIBGUESTFS_CACHEDIR

cd /mnt/storage/ova/

# convertir
# ref: https://libguestfs.org/virt-v2v.1.html
# server-id: nom dans openstack de cette VM de travail
# guest-id: nom de la vm à traiter qui sera indiqué en nom et description des volumes openstack
TARGET_VM=SRV
virt-v2v -i ova ${TARGET_VM}.ova -o openstack  -oo server-id=$HOSTNAME  -oo guest-id=${TARGET_VM}

# Les erreurs "read-only access" sont sans incidence

# une fois terminé, les vmdk sont importés en volumes indépendants
openstack volume list |grep -i ${TARGET_VM}
```

la VM doit être créée manuellement

L'activation du boot uefi est déjà positionné par virt-v2v via les metadata/image-property du volume de boot


### Finitions 
appliquer certains paramètres recommandés, sur le disque de boot sda.  

* mode virtio-scsi => plus récent que virtio-blk pour la gestion des disques (Linux uniquement)
* qemu-guest-agent => permet le freeze du filesystem lors de la création de snapshots
* hw_vif_multiqueue => gestion du multiqueue sur les interfaces réseau virtio

```
# tous serveurs
openstack volume set ${TARGET_VM}-sda \
	--image-property hw_qemu_guest_agent=yes  \
	--image-property hw_vif_multiqueue_enabled=true
```

### Optimisation de performances disque

*Serveurs linux uniquement*
Par défaut est utilisé le driver disque virtio. 
Le driver scsi-virtio est disponible, mais peut avoir des effets de bords car modifiant les lettres des disques.

Modifier le volume de boot (sda) avec les parametres suivants :
```
openstack volume set ${TARGET_VM}-sda \
	--image-property hw_disk_bus=scsi  \
	--image-property hw_scsi_model=virtio-scsi
```

Si les disques sont déjà montés, aucun changement.  
Par contre, si les disques sont associés par la suite à une vm, ils passeront de /dev/vd?? en /dev/sd?? .  
Il sera nécessaire de modifier le fstab en mode de récupération.  
