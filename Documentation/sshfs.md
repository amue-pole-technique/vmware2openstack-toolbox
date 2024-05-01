
# sshfs

Permet de monter un répertoire sur une machine distante via ssh.  
Alternative à NFS lorsque se posent des contraintes d'accès / ouvertures de ports.

Contrainte: les droits d'accès au répertoire distant sont dépendants du user de connexion utilisé.

## installation

Installation du package sshfs (pour rhel/centos, utiliser fuse-sshfs)
```
sudo apt-get install sshfs
```

Nb: Suivant la version, le package `fuse` peut être remplacé par `fuse3` automatiquement


## Usage

Contexte:  

* répertoire distant: /mnt/storage
* point de montage local: /data/migration/ova


Monter un repertoire distant
Le parametre `allow_other` permet l'accès lors de switch de user via `su`
```
sshfs -o allow_other <user>@<ip ou hostname>:/mnt/storage /data/migration/ova
```

Retirer le montage (alternative viable: reboot)
```
fusermount3 -u /data/migration/ova
```

