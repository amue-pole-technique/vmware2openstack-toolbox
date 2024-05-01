# export dans un fichier csv d'un serveur DNS Windows

La zone dns existe probablement sous le répertoire `c:\windows\system32\dns\` en tant que fichier .dns  
Ce dernier est au format bind.  

Cependant, s'il s'agit d'une zone intégrée dans un AD, il se peut qu'il n'y ait pas de fichier .dns local.  
Un export en csv via powershell reste possible.  


Ouvrir une fenetre powershell en mode admin et copier/coller le script ci-après.  
Changer sur la dernière commande le chemin du fichier csv en sortie, si necessaire

```
$results = foreach ($zone in (Get-DnsServerZone).ZoneName ) {
    foreach ($record in Get-DnsServerResourceRecord $zone)
    {
        $rData = switch ( $record.RecordType ) {
            'A'     { $record.RecordData.IPv4Address }
            'CNAME' { $record.RecordData.HostnameAlias }
            'NS'    { $record.RecordData.NameServer }
            'SOA'   { $record.RecordData.PrimaryServer }
            'SRV'   { $record.RecordData.DomainName }
            'PTR'   { $record.RecordData.PtrDomainName }
            'MX'    { $record.RecordData.MailExchange }
            'AAAA'  { $record.RecordData.IPv6Address }
            'TXT'   { $record.RecordData.DescriptiveText }
        }

        [PSCustomObject]@{
            ZoneName   = $zone
            HostName   = $record.HostName
            RecordType = $record.RecordType
            TimeToLive = $record.TimeToLive
            RecordData = $rData
        }
    }
}
# $results | Out-GridView
$results | Export-Csv -Path C:\temp\DNSRecords.csv -NoTypeInformation
```
