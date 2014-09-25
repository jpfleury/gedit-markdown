menagePot:
	rm -f plugins/markdown-preview/markdown-preview/locale/markdown-preview.pot
	# À faire, sinon `xgettext -j` va planter en précisant que le fichier est introuvable.
	touch plugins/markdown-preview/markdown-preview/locale/markdown-preview.pot

mo:
	for po in $(shell find plugins/markdown-preview/markdown-preview/locale/ -name *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done

po: pot
	for po in $(shell find plugins/markdown-preview/markdown-preview/locale/ -name *.po);\
	do\
		msgmerge -o tempo $$po plugins/markdown-preview/markdown-preview/locale/markdown-preview.pot;\
		rm $$po;\
		mv tempo $$po;\
	done

pot: menagePot
	xgettext -j -o plugins/markdown-preview/markdown-preview/locale/markdown-preview.pot -L Python plugins/markdown-preview/markdown-preview/__init__.py
