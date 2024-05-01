Action à effectuer sur une VM importée mais avec une configuration réseau statique  
la rendant inacessible

Au préalable, prendre la main sur la VM via la console.  
Redémarrer le serveur, jusqu'à obtenir l'affichage du menu grub.  
Presser immédiatement la fleche du haut ou du bas pour déplacer la sélection et stopper le compteur du timeout.  

```
menu grub => e pour éditer la 1er ligne => aller vers la fin sur la longue ligne de chargement du kernel (contenant vmlinuz), et rajouter à la fin :
	rw init=/bin/bash

Attention: supprimer les paramètres suivant si l'un ou les deux sont présents dans la ligne du kernel :  
  * `console=ttyS0,...` 
  * `crashkernel=auto`

Puis "ctrl x" pour lancer le démarrage


Ensuite : 
alias ll="ls -la"

# config reseau
cd /etc/sysconfig/network-scripts
mkdir bak
mv route-* bak/
# attention, ne pas embarquer ifcfg-lo
mv ifcfg-eth* bak/

# note: remplacer vi par nano au besoin
vi ifcfg-eth0
# ajouter ce qui suit entre #----------
#----------
BOOTPROTO=dhcp
DEVICE=eth0
ONBOOT=yes
#----------

vi /etc/sysconfig/network
# retirer les lignes suivantes : 
  GATEWAYDEV
  GATEWAY


# fstab
lsblk
cat /etc/fstab
# s'il y a des volumes /dev/vd?? alors que lsblk indique /dev/sd??, les modifier en sd??
# s'il y a des volume NFS, les commenter (avec "alt 35" ou sous vim, y pour copy du caractère sous le curseur, p pour paste)


# /etc/hosts
vi /etc/hosts
# supprimer toutes les lignes sauf 127.0.0.1 et ::1


# sshd
vi /etc/ssh/sshd_config
# modifier les listenaddress pour avoir: < listenAddress 0.0.0.0 > ou les supprimer
# aller sur la fin et retirer tout allow/deny sur adresses IP et users


# xinetd
# note: les fichiers xinetd.d/sshd-* peuvent être absents
rm /etc/hosts.deny
rm /etc/hosts.allow
rm /etc/xinetd.d/sshd-*

# service sshd lancé par xinetd
# inutile si xinetd n'est pas utilisé
# ne fonctionne pas: systemctl enable sshd  => creer le symlink manuellement
# les espaces et le \ sont pour la lisibilité, non obligatoires
ln -sf   /usr/lib/systemd/system/sshd.service   \
        /etc/systemd/system/multi-user.target.wants/


# dans le cas d'absence de user de connexion admin
# creation du user amue avec les droits sudo - sans home dans le cas où /home est sur un disque LVM
# il faudra faire une 1ere connexion apres reboot pour créer le répertoire /home/amue (propriétaire: amue:amue)
/sbin/useradd --no-create-home amue
/sbin/usermod --append --groups wheel amue
/bin/passwd amue


# Reboot du serveur
echo b > /proc/sysrq-trigger
# Alternative: hard reboot via openstack - ne pas utiliser soft reboot => plantage et nécessité d'attendre le timeout
```

----------------------
Problème de timeout waiting for device dev-vda1.device  
=> https://github.com/lavabit/robox/issues/152  
=> serveur source: montage /dev/sda1  sur /boot  | serveur cible: montage /dev/vda1 sur /boot  
Vérifier que le fstab n'indique pas un /dev/vd?? alors que lsblk liste des disque en /dev/sd??  


Probleme avec selinux qui bloque au boot sur des fichiers non enregistrés
Redémarrer en mode de récupération, et créer un fichier autorelabel
```
touch /.autorelabel
# redémarrer le serveur
```

