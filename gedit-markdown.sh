#!/bin/bash

# This file is part of gedit-markdown.
# Author: Jean-Philippe Fleury <contact@jpfleury.net>
# Copyright © 2009 Jean-Philippe Fleury

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

########################################################################
##
## Fonctions.
##
########################################################################

# Note that if a directory doesn't have read permissions, the function can't
# test if it contains files.
isEmpty()
{
	if [[ -d $1 && -r $1 ]]; then
		shopt -s nullglob dotglob
		files=("$1"/*)
		shopt -u nullglob dotglob
		
		if [[ ${#files[@]} == 0 ]]; then
			return 0
		fi
	fi
	
	return 1
}

supprimerDossiersVides()
{
	for dossier in "$@"; do
		while isEmpty "$dossier"; do
			rmdir -v "$dossier"
			dossier=$(dirname "$dossier")
		done
	done
}

supprimerGreffon()
{
	# Suppression des fichiers.
	for fichier in "${fichiersAsupprimer[@]}"; do
		rm -vf "$fichier"
	done
	
	# Suppression des dossiers.
	
	rm -rfv "$cheminPluginsMarkdownPreview"
	dossiersVidesAsupprimer=()
	
	dossiersVidesAsupprimer+=(
		"$cheminConfig"
		"$cheminLanguageSpecs"
		"$cheminPlugins"
		"$cheminPluginsMarkdownPreview"
		"$cheminSnippets"
		"$cheminStyles"
		"$cheminTools"
	)
	
	supprimerDossiersVides "${dossiersVidesAsupprimer[@]}"
}

########################################################################
##
## Variables.
##
########################################################################

####################################
## Mise en forme de l'affichage.
####################################

gras=$(tput bold)
normal=$(tput sgr0)

####################################
## Chemins.
####################################

if [[ -n $XDG_DATA_HOME ]]; then
	cheminLanguageSpecs=$XDG_DATA_HOME/gtksourceview-3.0/language-specs
	cheminPlugins=$XDG_DATA_HOME/gedit/plugins
	cheminPluginsMarkdownPreview=$XDG_DATA_HOME/gedit/plugins/markdown-preview
	cheminStyles=$XDG_DATA_HOME/gtksourceview-3.0/styles
else
	cheminLanguageSpecs=$HOME/.local/share/gtksourceview-3.0/language-specs
	cheminPlugins=$HOME/.local/share/gedit/plugins
	cheminPluginsMarkdownPreview=$HOME/.local/share/gedit/plugins/markdown-preview
	cheminStyles=$HOME/.local/share/gtksourceview-3.0/styles
fi

cheminSystemeLanguageSpecs=/usr/share/gtksourceview-3.0/language-specs
cheminSystemeSnippets=/usr/share/gedit/plugins/snippets

if [[ -n $XDG_CONFIG_HOME ]]; then
	cheminSnippets=$XDG_CONFIG_HOME/gedit/snippets
	cheminTools=$XDG_CONFIG_HOME/gedit/tools
else
	cheminSnippets=$HOME/.config/gedit/snippets
	cheminTools=$HOME/.config/gedit/tools
fi

if [[ -n $XDG_CONFIG_HOME ]]; then
	cheminConfig=$XDG_CONFIG_HOME/gedit
else
	cheminConfig=$HOME/.config/gedit
fi

cheminFichierConfig=$cheminConfig/gedit-markdown.ini

####################################
## Fichiers à supprimer.
####################################

fichiersAsupprimer=(
	"$cheminLanguageSpecs/markdown.lang"
	"$cheminLanguageSpecs/markdown-extra.lang"
	"$cheminPlugins/markdown-preview.gedit-plugin"
	"$cheminSnippets/markdown.xml"
	"$cheminSnippets/markdown-extra.xml"
	"$cheminStyles/classic-markdown.xml"
	"$cheminTools/export-to-html"
)

########################################################################
##
## Début du script.
##
########################################################################

cd "$(dirname "$0")"

if [[ $1 == install ]]; then
	echo "############################################################"
	echo "##"
	echo "## Installation of gedit-markdown"
	echo "##"
	echo "############################################################"
	echo
	# Au cas où il s'agit d'une mise à jour et non d'une première installation.
	supprimerGreffon
	
	# Création des répertoires s'ils n'existent pas déjà.
	mkdir -pv "$cheminConfig" "$cheminLanguageSpecs" "$cheminPlugins" "$cheminSnippets" \
		"$cheminStyles"
	
	# Copie des fichiers.
	cp -v config/gedit-markdown.ini "$cheminFichierConfig"
	cp -v language-specs/markdown-extra.lang "$cheminLanguageSpecs"
	cheminLanguageSpecsMarkdownLang=$cheminLanguageSpecs/markdown-extra.lang
	cp -v snippets/markdown-extra.xml "$cheminSnippets"
	
	# Outil externe.
	mkdir -pv "$cheminTools"
	cp -v tools/export-to-html "$cheminTools"
	chmod +x "$cheminTools/export-to-html"
	cp -v tools/export-to-pdf "$cheminTools"
	chmod +x "$cheminTools/export-to-pdf"
	
	# Greffon «Aperçu Markdown».
	cp -rv plugins/markdown-preview/* "$cheminPlugins"
	rm -v "$cheminPluginsMarkdownPreview/locale/markdown-preview.pot"
	find "$cheminPluginsMarkdownPreview/locale/" -name "*.po" -exec rm -vf {} \;
	
	cp -v styles/classic-markdown.xml "$cheminStyles"
	
	echo "$gras"
	echo "Installation successful. Please restart gedit (if it's already running)."
	echo "$normal"
	
	exit 0
elif [[ $1 == uninstall ]]; then
	echo "############################################################"
	echo "##"
	echo "## Uninstallation of gedit-markdown"
	echo "##"
	echo "############################################################"
	echo
	supprimerGreffon
	echo "$gras"
	echo "Uninstallation successful. Please restart gedit (if it's already running)."
	echo "$normal"
	
	exit 0
else
	echo "$gras"
	echo "Usage: $0 [install|uninstall]"
	echo "$normal"
	
	exit 1
fi
