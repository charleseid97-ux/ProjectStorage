#!/bin/bash
#
#script de packaging des fichiers modifiés depuis le commit passé en paramètre
#	$1 : SHA du commit, nom du tag, ou autre référence au format git diff (ex Id1..Id2)
#	$2 : dossier dans lequel construire le package (ex : ../tempPackage)

# lister les fichiers modifiés depuis le commit passé en paramètre
# exclut les fichiers supprimés et ceux modifiés dans le commit



#Liste des dossiers contenant des fichiers -meta.xml : rarement modifiés, mais doivent être embarqués dans le package si la classe/page/etc. évolue
#une liste un peu plus complète, mais nécessite d'être nettoyée (dossiers de rapport, email templates ...) : find -name '*-meta.xml' -printf '%h\n' | sort -u
LIST_META_XML_FOLDERS="classes components pages triggers"
LIST_META_LWC_FOLDERS="lwc aura email" #dossiers contenant des sous-dossiers avec des fichiers et leur -meta.xml (ex: email/dossier1/template.email-meta.xml)
#dossiers ayant eux-même des fichier meta associés, avec leurs extensions (ex: le dossier staticresources/RS_CRM/ doit être déployé avec le fichier staticresources/RS_CRM.resource-meta.xml
LIST_META_OTHER_FOLDERS="staticresources"
declare -A LIST_META_OTHER_FOLDERS_EXTENSIONS
LIST_META_OTHER_FOLDERS_EXTENSIONS["staticresources"]=".resource"
LIST_META_OTHER_FOLDERS_EXTENSIONS["otherfolder"]=".otherextension"


if [ -v ${2} ]
	then PACKAGE_DIR="../tempPackage"
	else PACKAGE_DIR="./"${2}
fi

REV_RANGE=${1}

#si un seul commit est spécifié, on complète le paramètre avec ..HEAD
if [[ ${1} != *".."* ]];
	then REV_RANGE=${1}"..HEAD";
fi

#variable inutilisée pour le moment
LOG_FILE="../extract_files_since_commit.log"

echo "Ce script va extraire les fichiers modifiés depuis le commit ${REV_RANGE} dans le dossier "${PACKAGE_DIR}


read -n 1 -s -p "Appuyez sur une touche pour continuer ..."

echo "Démarrage de la copie."

rm -rf ${PACKAGE_DIR}
mkdir -p ${PACKAGE_DIR}

#copie des fichiers sfdx-project.json et .forceignore nécessaires pour les commandes SFDX
cp -f sfdx-project.json ${PACKAGE_DIR}/
cp -f .forceignore ${PACKAGE_DIR}/

#liste des fichiers modifiés/à déployer
git diff --name-only -z --diff-filter=ACMRT ${REV_RANGE} | xargs -0 -I % cp --parents % "${PACKAGE_DIR}/"

#ajout des fichier de metadonnées qui n'ont pas été modifiés, mais nécessaires pour le déploiement
for SUBFOLDER in ${LIST_META_XML_FOLDERS}
do
	echo "récupération des fichiers -meta.xml dans le répertoire ./force-app/main/default/${SUBFOLDER} (s'il existe)"
	if [ -d "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" ]; then
		LIST_APEX_FILES=`ls "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" | sort | uniq`
		for APEX_FILE in ${LIST_APEX_FILES}
		do
			echo "./force-app/main/default/${SUBFOLDER}/${APEX_FILE}-meta.xml ${PACKAGE_DIR}/"
			cp --parents "./force-app/main/default/${SUBFOLDER}/${APEX_FILE}-meta.xml" "${PACKAGE_DIR}/"
			#copie également le fichier principal (uniquement s'il n'existe pas, -n = sans ecrasement) + Strip Ref : http://landoflinux.com/linux_bash_scripting_substring_tests.html
			cp --parents -n "./force-app/main/default/${SUBFOLDER}/${APEX_FILE%-meta.xml}" "${PACKAGE_DIR}/"
		done
	fi
done

for SUBFOLDER in ${LIST_META_OTHER_FOLDERS}
do
	echo "récupération des fichiers -meta.xml dans le répertoire ./force-app/main/default/${SUBFOLDER} (s'il existe)"
	if [ -d "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" ]; then
		LIST_OTHER_FOLDERS=`ls "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" | sort | uniq`
		for OTHER_FOLDER in ${LIST_OTHER_FOLDERS}
		do
			#cas particulier des static resources : on peut avoir des fichiers (image, texte / ex: testGmAppParam.txt) et des dossiers (pour des resources zippées / ex: RS_CRM)
			# les fichiers -meta.xml ont deux formats possibles
			#	nom_de_dossier-meta.xml (ex: RS_CRM-meta.xml)
			#	nom_du_fichier_sans_extension-meta.xml
			# pour cette raison, on enlève l'extension des nomde fichiers (ex: testGmAppParam.txt => testGmAppParam-meta.xml)
			# c'est ce que fait le "%.*" dans ${OTHER_FOLDER%.*} (retirer le dernier point et ce qui suit dans le nom)
			#	https://stackoverflow.com/questions/12152626/how-can-i-remove-the-extension-of-a-filename-in-a-shell-script
			#	https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
			FILE_TO_COPY="./force-app/main/default/${SUBFOLDER}/${OTHER_FOLDER%.*}${LIST_META_OTHER_FOLDERS_EXTENSIONS[${SUBFOLDER}]}-meta.xml"
			echo "copie de ${FILE_TO_COPY} vers ${PACKAGE_DIR}/"
			cp --parents ${FILE_TO_COPY} "${PACKAGE_DIR}/"
		done
	fi
done

#Copie de tous les fichiers présent dans les répertoires staticresources qui sont extrait afin de reconstruire la ressource au complet
for SUBFOLDER in ${LIST_META_OTHER_FOLDERS}
do
	echo "récupération des fichiers resources dans le répertoire ./force-app/main/default/${SUBFOLDER} (s'il existe)"
	if [ -d "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" ]; then
	LIST_OTHER_FOLDERS=`ls -d  ../tempPackage/force-app/main/default/staticresources/*/ | sed "s#.*/staticresources/\([^/]*\).*#\1#" | sort | uniq`
	for OTHER_FOLDER in ${LIST_OTHER_FOLDERS}
	do
		FILE_TO_COPY="./force-app/main/default/${SUBFOLDER}/${OTHER_FOLDER}/*"
		echo "copie de ${FILE_TO_COPY} vers ${PACKAGE_DIR}/"
		cp -r ${FILE_TO_COPY} "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}/${OTHER_FOLDER}/"
	done
	fi
done

for SUBFOLDER in ${LIST_META_LWC_FOLDERS}
do
	echo "récupération des bundle lightning dont les fichiers -meta.xml dans le répertoire ./force-app/main/default/${SUBFOLDER} (s'il existe)"
	if [ -d "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" ]; then
		LIST_COMPOS=`ls "${PACKAGE_DIR}/force-app/main/default/${SUBFOLDER}" | sort | uniq`
		for COMPO_BUNDLE in ${LIST_COMPOS}
		do
			echo "./force-app/main/default/${SUBFOLDER}/${COMPO_BUNDLE} ${PACKAGE_DIR}/"
			cp --parents --recursive "./force-app/main/default/${SUBFOLDER}/${COMPO_BUNDLE}" "${PACKAGE_DIR}/"
		done
	fi
done

ant -buildfile ./build_tools/duplicate_code/build.xml CPDTask
echo "Veuillez consulter les rapports de code dupliqué dans ./build_tools/duplicate_code/html/."

if [ -n "$(ls -A ../tempPackage/force-app/main/default/classes)" ]; then
	java -jar build_tools/ApexCleaner.jar ../tempPackage/force-app/main/default/classes/ ../tempPackage/force-app/main/default/cleaned/
	mv ../tempPackage/force-app/main/default/cleaned/* ../tempPackage/force-app/main/default/classes/
fi

if [ -n "$(ls -A ../tempPackage/force-app/main/default/triggers)" ]; then
	java -jar build_tools/ApexCleaner.jar ../tempPackage/force-app/main/default/triggers/ ../tempPackage/force-app/main/default/cleaned/
	mv ../tempPackage/force-app/main/default/cleaned/* ../tempPackage/force-app/main/default/triggers/
fi

rm -r ../tempPackage/force-app/main/default/cleaned/

echo "Copie terminée."

BRANCHNAME=$(git branch --show-current)
BRANCHNAME=${BRANCHNAME//\//-}
cp "./dataloaderScriptsV2/bin/chargementsDataLoaderV2"*.bat "${PACKAGE_DIR}/dataloaderScriptsV2/bin/"

#génération du changelog
CHGLG="${PACKAGE_DIR}/changelog.html"

echo ' <html> <style> .tooltip {   position: relative;    }  .tooltip .tooltiptext {   visibility: hidden;   width: 100%;   background-color: black;   color: #fff;   text-align: center;   border-radius: 6px;   padding: 5px 0;   position: absolute;   z-index: 1;   top: 100%;   left: 0%;   margin-left: -60px; }  .tooltip .tooltiptext::after {   content: "";   position: absolute;   bottom: 100%;   left: 50%;   margin-left: -5px;   border-width: 5px;   border-style: solid;   border-color: transparent transparent black transparent; }  .tooltip:hover .tooltiptext {   visibility: visible; }  table {border-collapse: collapse;     font-family: Tahoma, Geneva, sans-serif; } table td {padding: 15px; } table thead td {background-color: #54585d;color: #ffffff;font-weight: bold;font-size: 13px;border: 1px solid #54585d; } table tbody td {color: #636363;border: 1px solid #dddfe1; } table tbody tr {background-color: #f9fafb; } table tbody tr:nth-child(odd) {background-color: #ffffff; } </style> <body style="text-align:center;">  <h2>Change Log Qualif</h2>  <table><thead><tr> <td>Link</td> <td>Qui</td> <td>Date</td> <td>Sujet</td></tr></thead><tbody>' > ${CHGLG}
git log ${REV_RANGE} --pretty=format:'<tr><td><a href="https://development-carmignac-tools.visualstudio.com/DBS/_git/Salesforce/commit/%H">afficher le commit</a></td><td>%cn</td><td>%cd</td><td class="tooltip"> %s<span class="tooltiptext">Informations complémentaires: %b</span></td></tr> ' --reverse --date=format:%d/%m/%Y >> ${CHGLG}
echo '</tbody></table></body></html>' >> ${CHGLG}

cd ${PACKAGE_DIR}

echo "conversion des sources au format metadata dans le dossier ${PACKAGE_DIR}/src"
sfdx force:source:convert -d src
#copie des packages de suppression de composants
cp manifest/destructive* src
echo "le package est prêt à être déployé depuis le dossier ${PACKAGE_DIR}/src avec la commande 'sfdx force:mdapi:deploy -d ../tempPackage/src -u username'"

echo "preparation des chargements Data Loader"
echo ${BRANCHNAME} > ${PACKAGE_DIR}/dataloaderScriptsV2/bin/actual-version.config

echo "- renommage des batchs"
DATALOADER_BAT_DIR="${PACKAGE_DIR}/dataloaderScriptsV2/bin/bat/*.bat"
for BAT_FILE_PATH in $DATALOADER_BAT_DIR
do
	BAT_FILE_NAME=$(basename $BAT_FILE_PATH)
	echo Renommage du batch DataLoader $BAT_FILE_NAME en ${BRANCHNAME}_${BAT_FILE_NAME}
	mv -- "${PACKAGE_DIR}/dataloaderScriptsV2/bin/bat/${BAT_FILE_NAME}" "${PACKAGE_DIR}/dataloaderScriptsV2/bin/bat/${BRANCHNAME}_${BAT_FILE_NAME}"
done

echo "- renommage des process-conf"
DATALOADER_PROCESS_DIR="${PACKAGE_DIR}/dataloaderScriptsV2/bin/process-conf/*.xml"
for PROCESS_FILE_PATH in $DATALOADER_PROCESS_DIR
do
	PROCESS_FILE_NAME=$(basename $PROCESS_FILE_PATH)
	echo Renommage du processconf $PROCESS_FILE_NAME en ${BRANCHNAME}_${PROCESS_FILE_NAME}
	mv -- "${PACKAGE_DIR}/dataloaderScriptsV2/bin/process-conf/${PROCESS_FILE_NAME}" "${PACKAGE_DIR}/dataloaderScriptsV2/bin/process-conf/${BRANCHNAME}_${PROCESS_FILE_NAME}"
done

echo 'tout est pret, y compris les Data Loader'
