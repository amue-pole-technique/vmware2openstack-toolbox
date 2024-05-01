#!/bin/bash

TARGET_DIR="$1"
CURRENT_DIR=$( dirname $0 )
LOG_DIR=$( readlink -f $CURRENT_DIR/log )

IMPORT_SCRIPT=$CURRENT_DIR/openstack_v2v_ova_import.sh
CMD_ARG_SCRIPT=${0/.sh/.parme}
CMD_ARG_LST=""


_showUsage() {
    echo -e "
Syntaxe : 
	$( basename $0 )  '/path/containing/ova/or/ovf/files/'

Une recherche de fichiers .ova et .ovf recursive sera effectue dans le repertoire cible  
suivie par autant de lancements du script _import.sh que d'exports trouves.  


la presence d'un fichier '$( basename $CMD_ARG_SCRIPT )' contenant une ligne unique est supportee 
afin de permettre l'usage de parametres pour customiser le script _import.sh.
Ces parametres seront ajoutes a la fin de la commande : $( basename $IMPORT_SCRIPT ) --guest /path/to/file.ova

Exemple de ligne attendue : --os-network net-imported-vm --os-flavor-force m4.medium --os-this-vm-name migrate


Note : Un fichier log est genere par VM a traiter sous $LOG_DIR/
"
}


if [ $# -eq 0 ] || echo "$1" |egrep -i -q '\-(h|help|?|aide)$'; then _showUsage; exit 1; fi
if [ $UID -ne 0 ]; then echo "root or sudo required"; exit 1; fi
if [ ! -d "$TARGET_DIR" ]; then echo "Error: directory '$TARGET_DIR' not found"; exit 1; fi

if [ -s $CMD_ARG_SCRIPT ]; then
	echo "Fichier de parametres $CMD_ARG_SCRIPT present ..."
	CMD_ARG_LST=$( grep -v '^#' "$CMD_ARG_SCRIPT" )
	if [ $? -ne 0 ]; then exit 1; fi
    CMD_ARG_LST=$( echo "$CMD_ARG_LST" | head -1 )
	
	echo "Parametres recuperes: $CMD_ARG_LST"
fi

while read -r sTargetOva; do
	echo ""
	LOG_FILE="$LOG_DIR/$( basename $sTargetOva).log.$( date '+%Y%m%d-%H%M%S' )"
	if [ ! -d $LOG_DIR ]; then mkdir -p $LOG_DIR || exit 1; fi

	$IMPORT_SCRIPT --guest "$sTargetOva" $CMD_ARG_LST  2>&1 | tee -a $LOG_FILE
	#TODO: error control
    
done < <( find "$TARGET_DIR" -iname "*.ova" -o -iname "*.ovf" )

echo ""
echo "Logs are available in : $LOG_DIR/"
echo "Done"
