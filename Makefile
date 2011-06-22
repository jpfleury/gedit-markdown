########################################################################
##
## Variables.
##
########################################################################

# Chemin vers le bureau.
cheminBureau:=$(shell xdg-user-dir DESKTOP)

# Dossier de publication.
dossierPub=gedit-markdown

# Dernière version, représentée par la dernière étiquette.
version:=$(shell bzr tags | sort -k2n,2n | tail -n 1 | cut -d ' ' -f 1)

########################################################################
##
## Métacibles.
##
########################################################################

# Met à jour les fichiers qui sont versionnés, mais pas créés ni gérés à la main. À faire par exemple avant la dernière révision d'une prochaine version.
generer: po mo

# Crée l'archive; y ajoute les fichiers qui ne sont pas versionnés, mais nécessaires; supprime les fichiers versionnés, mais inutiles. À faire après un `bzr tag ...` pour la sortie d'une nouvelle version.
publier: fichiersSurBureau

########################################################################
##
## Cibles.
##
########################################################################

archive: changelog versionTxt
	bzr export -r tag:$(version) $(dossierPub)
	cp doc/ChangeLog $(dossierPub)/doc
	cp doc/version.txt $(dossierPub)/doc
	$(MAKE) moArchive
	rm -f $(dossierPub)/Makefile
	zip -qr gedit-markdown.zip $(dossierPub)
	rm -rf $(dossierPub)

changelog:
	# Est basé sur <http://telecom.inescporto.pt/~gjc/gnulog.py>. Ne pas oublier de mettre ce fichier dans le dossier des extensions de bazaar, par exemple `~/.bazaar/plugins/`.
	BZR_GNULOG_SPLIT_ON_BLANK_LINES=0 bzr log -v --log-format 'gnu' -r1..tag:$(version) > doc/ChangeLog

fichiersSurBureau: archive
	cp doc/ChangeLog $(cheminBureau)
	cp doc/LISEZ-MOI.mkd $(cheminBureau)
	cp doc/README.mkd $(cheminBureau)
	mv gedit-markdown.zip $(cheminBureau)

menagePot:
	rm -f locale/gedit-markdown.pot
	rm -f plugins/markdown-preview/locale/markdown-preview.pot
	# À faire, sinon `xgettext -j` va planter en précisant que le fichier est introuvable.
	touch locale/gedit-markdown.pot
	touch plugins/markdown-preview/locale/markdown-preview.pot

mo:
	for po in $(shell find locale/ -name *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done
	for po in $(shell find plugins/markdown-preview/locale/ -name *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done

moArchive:
	for po in $(shell find $(dossierPub)/locale/ -name *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done
	for po in $(shell find $(dossierPub)/plugins/markdown-preview/locale/ -name *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done

po: pot
	for po in $(shell find locale/ -name *.po);\
	do\
		msgmerge -o tempo $$po locale/gedit-markdown.pot;\
		rm $$po;\
		mv tempo $$po;\
	done
	for po in $(shell find plugins/markdown-preview/locale/ -name *.po);\
	do\
		msgmerge -o tempo $$po plugins/markdown-preview/locale/markdown-preview.pot;\
		rm $$po;\
		mv tempo $$po;\
	done

pot: menagePot
	xgettext -j -o locale/gedit-markdown.pot --from-code=UTF-8 -L shell gedit-markdown.sh
	xgettext -j -o plugins/markdown-preview/locale/markdown-preview.pot -L Python plugins/markdown-preview/__init__.py

push:
	bzr push lp:~jpfle/+junk/gedit-markdown

versionTxt:
	echo $(version) > doc/version.txt

