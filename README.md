# migration-toolbox

Outillage et documentation pour la migration de VMware vSphere vers Openstack KVM.  
Basés sur l'usage de l'outil virt-v2v.  

**ATTENTION : Ce projet est archivé. Aucune maintenance ni support ne sera effectué par ses auteurs.**  

Documentation fournie dans les sous-repertoires `documentation` et `virt-v2v_install`  
Les éléments suivants sont disponibles:  

* [Installation des éléments virt-v2v](virt-v2v_install/)
* [Manipuler un vmdk en cas de FS full](Documentation/Modification vmdk avec qemu et kpartx.md)
* [Post import  - recuperer la main sur une vm inaccessible](Documentation/Post import openstack - recuperer la main sur une vm importee.md)
* [Windows - récuperation des drivers Virtio signés par Redhat](Documentation/Drivers virtio depuis Red Hat.md)


## Utilisation des scripts openstack_v2v_ova

### openstack_v2v_ova_import.sh

Syntaxe: `./openstack_v2v_ova_import.sh --guest /path/to/ova/or/ovf/file.ov?`  

Aide intégrée via : `--help`


Script d'import d'un serveur virtuel VMware exporté au format OVA ou OVF.  
Il entoure l'outil virt-v2v permettant une fois les vmdk importés, de créer la VM et attacher les disques.  


**Prérequis:**  
* 4 Go de ram sur le serveur de migration
* accès au user root via sudo ou autre (obligatoire de part les outils utilisés)
* un token d'accès au projet openstack (niveau membre minimum) sourcé dans l'environnement  
* un répertoire /data/tmp de 5 à 10 Go d'espace libre (modifiable)  
* le serveur de migration devant avoir un nom identique dans openstack (modifiable)  
* le réseau cible recevant les VM importées nommé `net-migration` (modifiable)  


**Particularités:**  
Un appel au script _import_cleanup_linux est intégré afin de monter le volume systeme (sda) et effectuer certaines actions de nettoyage.  
L'activation de la partition root du volume systeme est parfois bloqué par l'incapacité de LVM à gérer des retraits de disques.  

En cas d'incapacité à effectuer les actions ou autre problème, une fois une fois la VM créée et la situation corrigée :  

* depuis openstack, supprimer la VM. Les volumes sont indépendants, ils ne seront pas supprimés.
* lancer `./openstack_v2v_ova_import.sh /path/to/file.ova  --skip_v2v-import`  

Ce paramètre saute l'étape de conversion des vmdk par virt-v2v.  
LVM devrait être alors plus conciliant suite à la correction ou reboot, permettant l'activation des volumes groups pour accéder à la partition systeme.  
Le script _cleanup sera alors exécuté, puis la vm recréee et les disques attachés à nouveau.  

Détail utile : la commande de création de l'instance openstack est affichée dans le log écran


---
### openstack_v2v_ova_loop.sh

Syntaxe: `./openstack_v2v_ova_loop.sh  /path/with/ova/files/`  

Aide intégrée via : `--help`


Script récupérant les export OVA présents dans le répertoire cible et tous ses sous-répertoires (récursif).  
Il appelle pour chaque ova le script _import.sh, et récupère la sortie écran dans un fichier log sous log/

L'usage d'un fichier de paramètre `openstack_v2v_ova_loop.parme` permet de customiser les lancements de _import.sh.  
Ce fichier est global, il n'y a pas de fonctionalité actuelle supportant un fichier .parme pour chaque VM.


---
### openstack_v2v_ova_import_cleanup_linux.sh

Syntaxe: `./openstack_v2v_ova_import_cleanup_linux.sh  /path/to/root/mount/`  

Script effectuant des manipulations sur un répertoire étant la partition root d'un disque secondaire.  
Les principaux éléments modifiés sont sous etc/  

Vu les actions, ce script intègre une sécurité pour ne pas traiter le répertoire `/` de migration lui-même, d'où l'absence de chroot.

Il est lancé automatiquement par openstack_v2v_ova_import.sh  
Retirer ce script est possible : un paramètre dans le script _import.sh est disponible pour ignorer cette étape.  
A défaut, un test de présence de ce script cleanup est effectué, et le retour d'exécution n'est pas contrôlé par le script _import.sh  

---
# Licence

[CeCILL-2.1](https://opensource.org/license/CECILL-2.1)

