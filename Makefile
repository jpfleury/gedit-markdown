LOCALEDIR = plugins/markdown-preview/markdown-preview/locale
INITPY = plugins/markdown-preview/markdown-preview/__init__.py

clean-pot:
	rm -f "$(LOCALEDIR)/markdown-preview.pot"
	touch "$(LOCALEDIR)/markdown-preview.pot"

pot: clean-pot
	xgettext -j -o "$(LOCALEDIR)/markdown-preview.pot" -L Python "$(INITPY)"

po: pot
	for po in $(shell find "$(LOCALEDIR)" -name '*.po'); do \
		msgmerge -o tempo "$$po" "$(LOCALEDIR)/markdown-preview.pot"; \
		rm "$$po"; \
		mv tempo "$$po"; \
	done

mo:
	for po in $(shell find "$(LOCALEDIR)" -name '*.po'); do \
		msgfmt -o "$${po%.*}.mo" "$$po"; \
	done
