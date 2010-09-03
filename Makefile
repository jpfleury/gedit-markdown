########################################################################
##
## Variables.
##
########################################################################

# Chemin vers le bureau.
bureau:=$(shell xdg-user-dir DESKTOP)

# Dernière version, représentée par la dernière étiquette.
version:=$(shell bzr tags | sort -k2n,2n | tail -n 1 | cut -d ' ' -f 1)

########################################################################
##
## Métacibles.
##
########################################################################

# Met à jour les fichiers qui sont versionnés, mais pas créés ni gérés à la main. À faire par exemple avant la dernière révision d'une prochaine version.
generer: po mo

# Crée l'archive ZIP; y ajoute les fichiers qui ne sont pas versionnés, mais nécessaires; supprime les fichiers versionnés, mais inutiles; copie ou déplace certains fichiers sur le bureau. À faire après un `bzr tag ...` pour la sortie d'une nouvelle version.
publier: archive

########################################################################
##
## Cibles.
##
########################################################################

archive: menage-archive ChangeLog version.txt
	bzr export -r tag:$(version) $(version)
	mv ChangeLog $(version)/
	cp version.txt $(version)/
	$(MAKE) mo-archive
	rm -f $(version)/Makefile
	zip -rv gedit-markdown.zip $(version)
	rm -rf $(version)
	mv gedit-markdown.zip $(bureau)/

ChangeLog: menage-ChangeLog
	# Est basé sur <http://telecom.inescporto.pt/~gjc/gnulog.py>. Ne pas oublier de mettre ce fichier dans le dossier des extensions de bazaar, par exemple `~/.bazaar/plugins/`.
	BZR_GNULOG_SPLIT_ON_BLANK_LINES=0 bzr log -v --log-format 'gnu' -r1..tag:$(version) > ChangeLog

menage-archive:
	rm -f gedit-markdown.zip

menage-ChangeLog:
	rm -f ChangeLog

menage-pot:
	rm -f locale/gedit-markdown.pot
	# À faire, sinon `xgettext -j` va planter en précisant que le fichier est introuvable.
	touch locale/gedit-markdown.pot

menage-version.txt:
	rm -f version.txt

mo:
	for po in $(shell find locale/ -iname *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done

mo-archive:
	for po in $(shell find $(version)/locale/ -iname *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done

po: pot
	for po in $(shell find ./ -iname *.po);\
	do\
		msgmerge -o tempo $$po locale/gedit-markdown.pot;\
		rm $$po;\
		mv tempo $$po;\
	done

pot: menage-pot
	find ./ -iname "gedit-markdown.sh" -exec xgettext -j -o locale/gedit-markdown.pot --from-code=UTF-8 -L shell {} \;

push:
	bzr push lp:~jpfle/+junk/gedit-markdown

version.txt: menage-version.txt
	echo $(version) > version.txt

