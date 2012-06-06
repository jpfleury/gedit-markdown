#!/bin/bash

# Le fichier gedit-markdown.sh fait partie de gedit-markdown.
# Auteur: Jean-Philippe Fleury <contact@jpfleury.net>
# Copyright © Jean-Philippe Fleury, 2009, 2011-2012.

# Ce programme est un logiciel libre; vous pouvez le redistribuer ou le
# modifier suivant les termes de la GNU General Public License telle que
# publiée par la Free Software Foundation: soit la version 3 de cette
# licence, soit (à votre gré) toute version ultérieure.

# Ce programme est distribué dans l'espoir qu'il vous sera utile, mais SANS
# AUCUNE GARANTIE: sans même la garantie implicite de COMMERCIALISABILITÉ
# ni d'ADÉQUATION À UN OBJECTIF PARTICULIER. Consultez la Licence publique
# générale GNU pour plus de détails.

# Vous devriez avoir reçu une copie de la Licence publique générale GNU avec
# ce programme; si ce n'est pas le cas, consultez
# <http://www.gnu.org/licenses/>.

########################################################################
##
## Localisation.
##
########################################################################

if type -p gettext > /dev/null; then
	export TEXTDOMAINDIR=./locale
	export TEXTDOMAIN=gedit-markdown
	
	if [[ ${LANG:0:2} == fr ]]; then
		export LANGUAGE=fr
	fi
	
	. gettext.sh
else
	gettext()
	{
		echo "$*"
	}
fi

########################################################################
##
## Fonctions.
##
########################################################################

# Merci à <http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format/4025065#4025065>.
compareVersions()
{
	if [[ $1 == $2 ]]; then
		return 0
	fi
	
	local IFS=.
	local i version1=($1) version2=($2)
	
	for ((i = ${#version1[@]}; i < ${#version2[@]}; ++i)); do
		version1[i]=0
	done
	
	for ((i = 0; i < ${#version1[@]}; ++i)); do
		if [[ -z ${version2[i]} ]]; then
			version2[i]=0
		fi
		
		if ((10#${version1[i]} > 10#${version2[i]})); then
			return 1
		fi
		
		if ((10#${version1[i]} < 10#${version2[i]})); then
			return 2
		fi
	done
	
	return 0
}

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
	
	for fichier in "${anciensFichiersAsupprimer[@]}"; do
		rm -vf "$fichier"
	done
	
	for fichier in "${fichiersAsupprimer[@]}"; do
		rm -vf "$fichier"
	done
	
	# Suppression des dossiers.
	
	rm -rfv "$cheminPluginsMarkdownPreview"
	dossiersVidesAsupprimer=()
	
	if [[ -n $cheminPythonSitePackages ]]; then
		rm -rfv "$cheminPythonSitePackages/markdown"
		dossiersVidesAsupprimer+=("$cheminPythonSitePackages")
	fi
	
	if [[ -n $ancienCheminPythonSitePackages ]]; then
		rm -rfv "$ancienCheminPythonSitePackages/markdown"
		dossiersVidesAsupprimer+=("$ancienCheminPythonSitePackages")
	fi
	
	dossiersVidesAsupprimer+=(
		"$cheminConfig"
		"$cheminLanguageSpecs"
		"$cheminPlugins"
		"$cheminPluginsMarkdownPreview"
		"$cheminSnippets"
		"$cheminStyles"
		"$cheminTools"
		
		# Anciennes versions.
		"$cheminInvalideGeditSnippets"
		"$cheminInvalideGeditTools"
		"$cheminMimePackages"
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
## Version de gedit.
####################################

if [[ $2 == 2 || $2 == 3 ]]; then
	versionGedit=$2
elif type -p gedit > /dev/null; then
	versionGedit=$(gedit --version | cut -d ' ' -f 4)
fi

####################################
## Chemins.
####################################

if [[ ${versionGedit:0:1} == 3 ]]; then
	# gedit 3.
	
	cheminGeditMarkdownPluginsGedit=plugins/gedit3
	
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
else
	# gedit 2.
	
	cheminGeditMarkdownPluginsGedit=plugins/gedit2
	
	if [[ -n $XDG_DATA_HOME ]]; then
		cheminLanguageSpecs=$XDG_DATA_HOME/gtksourceview-2.0/language-specs
		cheminStyles=$XDG_DATA_HOME/gtksourceview-2.0/styles
	else
		cheminLanguageSpecs=$HOME/.local/share/gtksourceview-2.0/language-specs
		cheminStyles=$HOME/.local/share/gtksourceview-2.0/styles
	fi
	
	cheminSystemeLanguageSpecs=/usr/share/gtksourceview-2.0/language-specs
	cheminPlugins=$HOME/.gnome2/gedit/plugins
	cheminPluginsMarkdownPreview=$HOME/.gnome2/gedit/plugins/markdown-preview
	cheminSnippets=$HOME/.gnome2/gedit/snippets
	cheminSystemeSnippets=/usr/share/gedit-2/plugins/snippets
	cheminTools=$HOME/.gnome2/gedit/tools
fi

if [[ -n $XDG_CONFIG_HOME ]]; then
	cheminConfig=$XDG_CONFIG_HOME/gedit
else
	cheminConfig=$HOME/.config/gedit
fi

ancienCheminFichierConfig=$HOME/.config/gedit-markdown.ini
cheminFichierConfig=$cheminConfig/gedit-markdown.ini

if [[ -f $cheminFichierConfig ]]; then
	ancienCheminPythonSitePackages=$(sed -n "s/^pythonSitePackages=\(.*\)$/\1/p" \
		< "$cheminFichierConfig")
fi

####################################
## Classe «no-spell-check» dans le fichier de langue.
####################################

# Le fichier de langue HTML est utilisé comme référence pour vérifier si la version
# installée de GtkSourceView supporte la classe «no-spell-check» dans les fichiers
# de langue.
cheminHtmlLang=$cheminSystemeLanguageSpecs/html.lang
supportClasseNoSpellCheck=true

if [[ -f $cheminHtmlLang && -z $(grep ' class="no-spell-check"' "$cheminHtmlLang") ]]; then
	supportClasseNoSpellCheck=false
fi

####################################
## Version de Python.
####################################

# Note: pour l'instant, Python 2.7 est la version la plus récente supportée par gedit.
# Python 3 ne sera donc pas considéré comme étant une bonne version, même si le greffon
# «Aperçu Markdown» le supporte.

bonneVersionPython=true

# Note: sous Archlinux, «/usr/bin/python» correspond à Python 3. On teste donc les
# chemins pour Python 2 en premier.
if type -p python2.7 > /dev/null; then
	binPython=$(type -p python2.7)
elif type -p python2.6 > /dev/null; then
	binPython=$(type -p python2.6)
elif type -p python2 > /dev/null; then
	binPython=$(type -p python2)
elif type -p python > /dev/null; then
	binPython=$(type -p python)
else
	bonneVersionPython=false
fi

if [[ $bonneVersionPython != false ]]; then
	versionPython=$("$binPython" -c "import sys; print(sys.version[:3])")
	
	if [[ ${versionPython:0:1} == 2 ]]; then
		compareVersions "$versionPython" "2.6"
		
		if [[ $? == 2 ]]; then
			bonneVersionPython=false
		else
			cheminPythonMarkdown=python-markdown/python2
			cheminPythonSitePackages=$("$binPython" -m site --user-site)
		fi
#	elif [[ ${versionPython:0:1} == 3 ]]; then
#		compareVersions "$versionPython" "3.1"
#		
#		if [[ $? == 2 ]]; then
#			bonneVersionPython=false
#		else
#			cheminPythonMarkdown=python-markdown/python3
#			cheminPythonSitePackages=$("$binPython" -m site --user-site)
#		fi
	else
		bonneVersionPython=false
	fi
fi

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
	"$cheminTools/export-extra-to-html"
)

# Fichiers d'anciennes versions.

cheminAncienFichierConfig=$HOME/.gedit-markdown.ini
cheminMimePackages=$HOME/.local/share/mime/packages

# Dossiers invalides utilisés un certain temps pour gedit 3.
cheminInvalideGeditSnippets=$HOME/.local/share/gedit/snippets
cheminInvalideGeditTools=$HOME/.local/share/gedit/tools

anciensFichiersAsupprimer=(
	"$cheminAncienFichierConfig"
	"$cheminInvalideGeditSnippets/markdown.xml"
	"$cheminInvalideGeditSnippets/markdown-extra.xml"
	"$cheminInvalideGeditTools/export-to-html"
	"$cheminInvalideGeditTools/export-extra-to-html"
	"$cheminMimePackages/x-markdown.xml"
	"$cheminPlugins/markdownpreview.gedit-plugin"
	"$cheminPlugins/markdownpreview.py"
	"$cheminPlugins/markdownpreview.pyc"
	"$cheminPlugins/markdown.py"
	"$cheminPlugins/markdown.pyc"
)

########################################################################
##
## Début du script.
##
########################################################################

cd "$(dirname "$0")"

if [[ $1 == installer || $1 == install ]]; then
	echo "$gras"
	echo "############################################################"
	echo "##"
	echo "## $(gettext "Installation de gedit-markdown")"
	echo "##"
	echo "############################################################"
	echo
	echo "## $(gettext "Première étape: vérification des dépendances")"
	echo "$normal"
	echo "- gedit: $versionGedit"
	echo "- Python: $versionPython"
	echo
	
	if [[ -z $versionGedit ]]; then
		gettext ""\
"Veuillez installer gedit avant de lancer le script d'installation de gedit-markdown."
		echo -e "\n"
		exit 1
	fi
	
	if [[ $supportClasseNoSpellCheck == false ]]; then
		echo -e "$(gettext ""\
"La vérification orthographique ne peut pas être désactivée dans la coloration\n"\
"syntaxique pour les contextes non pertinents (par exemple dans les adresses URL),\n"\
"car cette fonctionnalité dépend de GtkSourceView >= 2.10.")"
		echo
	fi
	
	if [[ $bonneVersionPython == false ]]; then
		echo -e "$(gettext ""\
"Le greffon «Aperçu Markdown» ne sera pas installé, car il dépend de Python 2 (>= 2.6)\n"\
"ou de Python 3 (>= 3.1).")"
		echo
	fi
	
	echo "$(gettext "Étape terminée.")"
	echo "$gras"
	echo "## $(gettext "Étape suivante: choix de la syntaxe Markdown à installer")"
	echo "$normal"
	echo -e "$(gettext ""\
"gedit-markdown peut ajouter le support du langage Markdown standard ou de la\n"\
"version spéciale Markdown Extra.\n"\
"\n"\
"\t1\tMarkdown standard\n"\
"\t2\tMarkdown Extra\n")"
	gettext "Saisissez votre choix [1/2] (2 par défaut): "
	read choix
	echo
	markdown=extra
	
	if [[ $choix == 1 ]]; then
		markdown=standard
		echo "$(gettext "Le langage Markdown standard sera ajouté.")"
	else
		echo "$(gettext "Le langage Markdown Extra sera ajouté.")"
	fi
	
	echo
	echo "$(gettext "Étape terminée.")"
	
	if [[ $bonneVersionPython == true ]]; then
		echo "$gras"
		message=$(gettext "Étape suivante: choix de l'emplacement de l'aperçu Markdown")
		echo "## $message"
		echo "$normal"
		message=$(gettext ""\
"L'aperçu Markdown peut être placé dans un des deux panneaux de gedit.\n"\
"\n"\
"\t1\tPanneau latéral\n"\
"\t2\tPanneau inférieur\n")
		echo -e "$message"
		gettext "Saisissez votre choix [1/2] (2 par défaut): "
		read choix
		echo
		panneau=bottom
		
		if [[ $choix == 1 ]]; then
			panneau=side
			gettext "L'aperçu Markdown se trouvera dans le panneau latéral."
			echo
		else
			gettext "L'aperçu Markdown se trouvera dans le panneau inférieur."
			echo
		fi
		
		echo
		echo "$(gettext "Étape terminée.")"
	fi
	
	echo "$gras"
	echo "## $(gettext "Étape suivante: copie des fichiers")"
	echo "$normal"
	
	# Au cas où il s'agit d'une mise à jour et non d'une première installation.
	supprimerGreffon
	
	# Création des répertoires s'ils n'existent pas déjà.
	mkdir -pv "$cheminConfig" "$cheminLanguageSpecs" "$cheminPlugins" "$cheminSnippets"\
		"$cheminStyles"
	
	# Copie des fichiers.
	
	if [[ -e $ancienCheminFichierConfig && ! -e $cheminFichierConfig ]]; then
		mv "$ancienCheminFichierConfig" "$cheminFichierConfig"
	elif [[ -e $ancienCheminFichierConfig && -e $cheminFichierConfig ]]; then
		rm -f "$ancienCheminFichierConfig"
	elif [[ ! -e $cheminFichierConfig ]]; then
		cp -v config/gedit-markdown.ini "$cheminFichierConfig"
	fi
	
	if [[ $markdown == standard ]]; then
		if [[ ! -e $cheminSystemeLanguageSpecs/markdown.lang ]]; then
			cp -v language-specs/markdown.lang "$cheminLanguageSpecs"
			cheminLanguageSpecsMarkdownLang=$cheminLanguageSpecs/markdown.lang
		fi
		
		if [[ ! -e $cheminSystemeSnippets/markdown.xml ]]; then
			cp -v snippets/markdown.xml "$cheminSnippets"
		fi
		
		# Mise à jour de la configuration.
		if [[ -n $(grep "^version=" "$cheminFichierConfig") ]]; then
			sed -i "s/^\(version=\).*$/\1standard/" "$cheminFichierConfig"
		else
			sed -i "s/^\(\[markdown-preview\]\)$/\1\nversion=standard/" "$cheminFichierConfig"
		fi
	else
		cp -v language-specs/markdown-extra.lang "$cheminLanguageSpecs"
		cheminLanguageSpecsMarkdownLang=$cheminLanguageSpecs/markdown-extra.lang
		cp -v snippets/markdown-extra.xml "$cheminSnippets"
	fi
	
	# Compatibilité avec GtkSourceView < 2.10.
	if [[ -f $cheminLanguageSpecsMarkdownLang ]]; then
		sed -i 's/ class="no-spell-check"//g' "$cheminLanguageSpecsMarkdownLang"
	fi
	
	if [[ $bonneVersionPython == true ]]; then
		# Python-Markdown.
		
		mkdir -pv "$cheminPythonSitePackages"
		cp -rv "$cheminPythonMarkdown" "$cheminPythonSitePackages/markdown"
		
		# Mise à jour de la configuration.
		if [[ -n $(grep "^pythonSitePackages=" "$cheminFichierConfig") ]]; then
			sed -i "s|^\(pythonSitePackages=\).*$|\1$cheminPythonSitePackages|"\
				"$cheminFichierConfig"
		else
			sed -i "s|^\(\[markdown-preview\]\)$|\1\npythonSitePackages=$cheminPythonSitePackages|"\
				$cheminFichierConfig
		fi
		
		# Outil externe.
		
		mkdir -pv "$cheminTools"
		cp -v tools/export-to-html "$cheminTools"
		
		if [[ $binPython != /usr/bin/python ]]; then
			sed -i "0,\|^#!/usr/bin/python$|s||#!$binPython|" "$cheminTools/export-to-html"
		fi
		
		# Greffon «Aperçu Markdown».
		
		cp -rv "$cheminGeditMarkdownPluginsGedit"/* "$cheminPlugins"
		rm -v "$cheminPluginsMarkdownPreview/locale/markdown-preview.pot"
		find "$cheminPluginsMarkdownPreview/locale/" -name "*.po" -exec rm -vf {} \;
		
		if [[ $panneau == side ]]; then
			# Mise à jour de la configuration.
			if [[ -n $(grep "^panel=" "$cheminFichierConfig") ]]; then
				sed -i "s/^\(panel=\).*$/\1side/" "$cheminFichierConfig"
			else
				sed -i "s/^\(\[markdown-preview\]\)$/\1\npanel=side/" "$cheminFichierConfig"
			fi
		fi
	fi
	
	cp -v styles/classic-markdown.xml "$cheminStyles"
	echo
	echo "$(gettext "Étape terminée.")"
	echo "$gras"
	gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert."
	echo
	echo "$normal"
	
	exit 0
elif [[ $1 == desinstaller || $1 == uninstall ]]; then
	echo "$gras"
	echo "############################################################"
	echo "##"
	echo "## $(gettext "Désinstallation de gedit-markdown")"
	echo "##"
	echo "############################################################"
	echo
	echo "## $(gettext "Première étape: suppression des fichiers")"
	echo "$normal"
	supprimerGreffon
	echo
	echo "$(gettext "Étape terminée.")"
	echo "$gras"
	gettext "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert."
	echo
	echo "$normal"
	
	exit 0
else
	echo "$gras"
	echo "$(gettext "Usage:") $0 $(gettext "ACTION [VERSION]")"
	echo "$normal"
	echo "$(gettext ""\
"ACTION (obligatoire): action à effectuer. Valeurs possibles:") installer|desinstaller"
	echo "$(gettext ""\
"VERSION (optionnel): version majeure de gedit. Valeurs possibles:") 2|3"
	echo
	
	exit 1
fi

