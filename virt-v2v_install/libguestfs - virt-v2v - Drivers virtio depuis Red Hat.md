
# Drivers VirtIO Windows

Les drivers sont initialement mis à disposition par Fedora  
ref: https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/  
ref2: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/  => stable  

Cependant, ces derniers ne disposent pas d'une signature Microsoft WHQL en tant que drivers.  
Redhat fourni de son coté ces drivers, avec cette signature WHQL.  
La présence de cette signature permet l'usage du secure boot lorsque la VM dispose d'un bios UEFI.  

Ces drivers signés sont récupérables depuis n'importe quel serveur RHEL enregistré.  
Utiliser une version de RHEL récente, puis :
```
sudo yum install virtio-win

=================================================================================================================================
 Package                  Architecture         Version                      Repository                                      Size
=================================================================================================================================
Installing:
 virtio-win               noarch               1.9.17-4.el8_4               rhel-8-for-x86_64-appstream-rpms               178 M

Transaction Summary
=================================================================================================================================
Install  1 Package

Total download size: 178 M
Installed size: 773 M
```

Une fois l'installation terminée, récupérer depuis `/usr/share/virtio-win/` les fichiers suivants :

* virtio-win.iso  
=> est utilisé par virt-v2v
* installer/virtio-win-guest-tools.exe  
=> pour installer le driver soi-même
