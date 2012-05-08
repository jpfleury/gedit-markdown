2to3:
	rm -rf python-markdown/python3
	cp -r python-markdown/python2 python-markdown/python3
	2to3 -w -n python-markdown/python3

menagePot:
	rm -f locale/gedit-markdown.pot
	rm -f plugins/gedit2/markdown-preview/locale/markdown-preview.pot
	rm -f plugins/gedit3/markdown-preview/locale/markdown-preview.pot
	# À faire, sinon `xgettext -j` va planter en précisant que le fichier est introuvable.
	touch locale/gedit-markdown.pot
	touch plugins/gedit2/markdown-preview/locale/markdown-preview.pot
	touch plugins/gedit3/markdown-preview/locale/markdown-preview.pot

mo:
	for po in $(shell find locale/ -name *.po);\
	do\
		msgfmt -o $${po%\.*}.mo $$po;\
	done
	for po in $(shell find plugins/*/markdown-preview/locale/ -name *.po);\
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
	for po in $(shell find plugins/gedit2/markdown-preview/locale/ -name *.po);\
	do\
		msgmerge -o tempo $$po plugins/gedit2/markdown-preview/locale/markdown-preview.pot;\
		rm $$po;\
		mv tempo $$po;\
	done
	for po in $(shell find plugins/gedit3/markdown-preview/locale/ -name *.po);\
	do\
		msgmerge -o tempo $$po plugins/gedit3/markdown-preview/locale/markdown-preview.pot;\
		rm $$po;\
		mv tempo $$po;\
	done

pot: menagePot
	xgettext -j -o locale/gedit-markdown.pot --from-code=UTF-8 -L shell gedit-markdown.sh
	xgettext -j -o plugins/gedit2/markdown-preview/locale/markdown-preview.pot -L Python plugins/gedit2/markdown-preview/__init__.py
	xgettext -j -o plugins/gedit3/markdown-preview/locale/markdown-preview.pot -L Python plugins/gedit3/markdown-preview/__init__.py

