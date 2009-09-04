########################################################################
##
## VARIABLES
##
########################################################################

# Chemin vers le bureau
bureau=`xdg-user-dir DESKTOP`

# Récupère le dernier tag (qui représente la dernière version)
tag=`bzr tags | tail -n 1 | cut -d ' ' -f 1`

# Récupère le numéro de la première révision du dernier tag
premiereRevTag=`bzr tags | tail -n 2 | head -n 1 | rev | cut -d ' ' -f 1 | rev | xargs expr 1 + `

########################################################################
##
## MÉTACIBLES
##
########################################################################

# Met à jour les fichiers qui sont versionnés, mais pas créés ni gérés à la main. À faire par exemple avant le dernier commit d'une prochaine version.
generer: po

# Crée une archive .bz2, y ajoute les fichiers qui ne sont pas versionnés mais nécessaires, supprime les fichiers versionnés mais inutiles. À faire après un bzr tag... quand une nouvelle version est sortie.
publier: archives

########################################################################
##
## CIBLES
##
########################################################################

archives: menage-archives ChangeLog version.txt
	bzr export -r tag:$(tag) $(tag)
	mv ChangeLog $(tag)/
	php ./scripts.cli.php mdtxt ChangeLogDerniereVersion
	mv ChangeLogDerniereVersion.mdtxt $(bureau)/ChangeLog-$(tag).mdtxt
	mv ChangeLogDerniereVersion $(tag)/
	cp version.txt $(tag)/
	cd $(tag) # Palliatif au fait que je n'ai pas trouvé comment insérer
	          # une variable de Makefile dans une commande shell $(...).
	          # Par exemple, ceci ne fonctionne pas:
	          # for po in $(find $(tag) -iname *.po);\
	for po in `find . -iname *.po`;\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done
	cd ../
	rm -f $(tag)/Makefile
	rm -f $(tag)/scripts.cli.php
	tar --bzip2 -cvf $(tag).tar.bz2 $(tag) # --bzip2 = -j
	zip -rv $(tag).zip $(tag)
	rm -rf $(tag)
	mv $(tag).tar.bz2 $(tag).tbz2 # Drupal bogue avec l'ajout de fichiers .tar.bz2
	mv $(tag).zip $(bureau)/
	mv $(tag).tbz2 $(bureau)/

ChangeLog: menage-ChangeLog
	# Est basé sur http://telecom.inescporto.pt/~gjc/gnulog.py
	# Ne pas oublier de mettre ce fichier dans le dossier de plugins de bzr,
	# par exemple ~/.bazaar/plugins/
	BZR_GNULOG_SPLIT_ON_BLANK_LINES=0 bzr log -v --log-format 'gnu' -r1..tag:$(tag) > ChangeLog
	BZR_GNULOG_SPLIT_ON_BLANK_LINES=0 bzr log -v --log-format 'gnu' -r revno:$(premiereRevTag)..tag:$(tag) > ChangeLogDerniereVersion

menage-archives:
	rm -f $(tag).tbz2
	rm -f $(tag).zip

menage-ChangeLog:
	rm -f ChangeLog
	rm -f ChangeLogDerniereVersion

menage-pot:
	rm -f locale/gedit-markdown.pot
	touch locale/gedit-markdown.pot # sinon xgettext -j va planter en précisant que le fichier est introuvable

menage-version.txt:
	rm -f version.txt

mo:
	for po in `find locale/ -iname *.po`;\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done

po: pot
	for po in `find ./ -iname *.po`;\
	do\
		msgmerge -o tempo $$po locale/gedit-markdown.pot;\
		rm $$po;\
		mv tempo $$po;\
	done

pot: menage-pot
	find ./ -iname "gedit-markdown.sh" -exec xgettext -j -o locale/gedit-markdown.pot --from-code=UTF-8 -L shell {} \;

version.txt: menage-version.txt
	echo $(tag) > version.txt

