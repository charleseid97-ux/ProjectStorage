#!/bin/bash
#
#script qui enlève de git les données necessaire uniquement pour la mep et vide les fichiers xml.
#
echo 'Début'

cp build_tools/empty-package.xml manifest/package.xml
cp build_tools/empty-package.xml manifest/destructiveChangesPost.xml
cp build_tools/empty-package.xml manifest/destructiveChangesPre.xml

git add manifest/package.xml
git add manifest/destructiveChangesPost.xml
git add manifest/destructiveChangesPre.xml
#on supprime tout le contenu du dossier dataloader/ à l'exception du readme.md
git rm --ignore-unmatch dataloader/* ":(exclude)dataloader/readme.md"
git rm --ignore-unmatch dataLoader/*
git rm --ignore-unmatch Dataloader/*
git rm --ignore-unmatch DataLoader/*
git rm --ignore-unmatch anonymousScript/*
git rm --ignore-unmatch anonymousscript/*
git rm --ignore-unmatch anonymousblock/*
git rm --ignore-unmatch anonymousBlock/*
git rm --ignore-unmatch anonymous/*
git rm --ignore-unmatch force-app/main/default/profiles/*
git rm --ignore-unmatch force-app/main/default/labels/*
git rm --ignore-unmatch force-app/main/default/sharingRules/*
git rm --ignore-unmatch force-app/main/default/workflows/*
#on supprime de façon ciblée le contenu du répertoire dataLoaderScripts afin de garder la structure, et les fichiers de template
git rm --ignore-unmatch dataloaderScripts/bin/* ":(exclude)dataloaderScripts/bin/template*.*" ":(exclude)dataloaderScripts/bin/example*.*"
git rm --ignore-unmatch dataloaderScripts/Data/In/* -r ":(exclude)dataloaderScripts/Data/In/readme*.md"
git rm --ignore-unmatch dataloaderScripts/Log/* ":(exclude)dataloaderScripts/Log/readme*.md"
git rm --ignore-unmatch dataloaderScripts/SDL/* ":(exclude)dataloaderScripts/SDL/readme*.md"
#on termine par une copie avec renommage des templates requis et on les track
cp dataloaderScripts/bin/templateProcess-conf.xml dataloaderScripts/bin/process-conf.xml
git add dataloaderScripts/bin/process-conf.xml
cp dataloaderScripts/bin/templateChargementsDataLoader.bat dataloaderScripts/bin/chargementsDataLoader.bat
git add dataloaderScripts/bin/chargementsDataLoader.bat
#on supprime de façon ciblée le contenu du répertoire dataloaderScriptsV2 afin de garder la structure, les batchs globaux et les fichiers de template
git rm --ignore-unmatch dataloaderScriptsV2/bin/bat/* ":(exclude)dataloaderScriptsV2/bin/bat/readme*.md"
git rm --ignore-unmatch dataloaderScriptsV2/bin/process-conf/* ":(exclude)dataloaderScriptsV2/bin/process-conf/readme*.md"
git rm --ignore-unmatch dataloaderScriptsV2/bin/*.* ":(exclude)dataloaderScriptsV2/bin/template*.*" ":(exclude)dataloaderScriptsV2/bin/example*.*" ":(exclude)dataloaderScriptsV2/bin/*.bat"
git rm --ignore-unmatch dataloaderScriptsV2/Data/In/* ":(exclude)dataloaderScriptsV2/Data/In/readme*.md"
git rm --ignore-unmatch dataloaderScriptsV2/Log/* ":(exclude)dataloaderScriptsV2/Log/readme*.md"
git rm --ignore-unmatch dataloaderScriptsV2/SDL/* ":(exclude)dataloaderScriptsV2/SDL/readme*.md"

#branche courante sur laquelle la suppression a lieu
BRANCH=`git rev-parse --abbrev-ref HEAD`

git commit -m "nettoyage $BRANCH"

git tag $BRANCH/`date +%y%m%d`

echo 'Fin -- vérifiez le commit avant de faire le push'