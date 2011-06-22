#!/bin/bash

# Le fichier gedit-markdown.sh fait partie de gedit-markdown.
# Auteur: Jean-Philippe Fleury <contact@jpfleury.net>
# Copyright © Jean-Philippe Fleury, 2009, 2011.

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

# Localisation.
export TEXTDOMAINDIR=`dirname "$0"`/locale
export TEXTDOMAIN=gedit-markdown
export LANGUAGE=$LANG
. gettext.sh

# Fonctions.

# Merci à <http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format/4025065#4025065>.
vercomp()
{
	if [[ $1 == $2 ]]; then
		return 0
	fi
	
	local IFS=.
	local i ver1=($1) ver2=($2)
	
	# fill empty fields in ver1 with zeros
	for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
		ver1[i]=0
	done
	
	for ((i=0; i<${#ver1[@]}; i++)); do
		if [[ -z ${ver2[i]} ]]; then
			# fill empty fields in ver2 with zeros
			ver2[i]=0
		fi
		
		if ((10#${ver1[i]} > 10#${ver2[i]})); then
			return 1
		fi
		
		if ((10#${ver1[i]} < 10#${ver2[i]})); then
			return 2
		fi
	done
	
	return 0
}

# Variables.

gras=$(tput bold)
normal=$(tput sgr0)

geditEstInstalle=1
bonneVersionGedit=1

if [ -z $(which gedit) ]; then
	geditEstInstalle=0
	bonneVersionGedit=0
else
	versionGedit=$(gedit --version | cut -d ' ' -f 4 | cut -d '.' -f 1)
	vercomp $versionGedit "2"
	
	if [[ $? == 1 ]]; then
		bonneVersionGedit=0
	fi
fi

vercomp $versionGedit "3"

# Dossiers pour gedit 3.
if [ $? == 0 ]; then
	cheminLanguageSpecs=~/.local/share/gtksourceview-3.0/language-specs
	cheminPlugins=~/.local/share/gedit/plugins
	cheminPluginsMarkdownPreview=~/.local/share/gedit/plugins/markdown-preview
	cheminSnippets=~/.local/share/gedit/snippets
	cheminStyles=~/.local/share/gtksourceview-3.0/styles
# Dossiers pour gedit 2.
else
	cheminLanguageSpecs=~/.local/share/gtksourceview-2.0/language-specs
	cheminPlugins=~/.gnome2/gedit/plugins
	cheminPluginsMarkdownPreview=~/.gnome2/gedit/plugins/markdown-preview
	cheminSnippets=~/.gnome2/gedit/snippets
	cheminStyles=~/.local/share/gtksourceview-2.0/styles
fi

bonneVersionPython=1

if [ -z $(which python) ]; then
	bonneVersionPython=0
else
	versionPython=$(python -c 'import sys; print(sys.version[:3])')
	vercomp $versionPython "2.6"
	
	if [[ $? == 2 ]]; then
		bonneVersionPython=0
	else
		cheminPythonSitePackages=$(python -m site --user-site)
	fi
fi

greffonEstInstallable=1

if [[ $bonneVersionGedit == 0 || $bonneVersionPython == 0 ]]; then
	greffonEstInstallable=0
fi

fichiersAsupprimer=( "$cheminLanguageSpecs/markdown.lang" "$cheminLanguageSpecs/markdown-extra.lang" "$cheminPlugins/markdown-preview.gedit-plugin" "$cheminSnippets/markdown.xml" "$cheminSnippets/markdown-extra.xml" "$cheminStyles/classic-markdown.xml" )

# Début du script.

cd `dirname "$0"`

if [[ $1 == "installer" || $1 == "install" ]]; then
	echo $gras
	echo "############################################################"
	echo "##"
	echo "## " $(gettext "Installation de gedit-markdown")
	echo "##"
	echo "############################################################"
	
	echo ""
	echo $(gettext "Étape 1: vérification des dépendances")
	echo $normal
	
	echo "- gedit: $versionGedit"
	echo "- Python: $versionPython"
	echo ""
	
	if [[ $geditEstInstalle == 0 ]]; then
		echo $(gettext "Veuillez installer gedit avant de lancer le script d'installation de gedit-markdown.")
		echo ""
		exit 1
	fi
	
	if [[ $greffonEstInstallable == 0 ]]; then
		echo $(gettext "Le greffon «Markdown Preview» ne sera pas installé, car il dépend de gedit 2 et de Python >= 2.6.")
		echo ""
	fi
	
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo $(gettext "Étape 2: choix de la syntaxe Markdown à installer")
	echo $normal
	
	echo -en $(gettext ""\
"gedit-markdown peut ajouter le support du langage Markdown standard ou de la\n"\
"version spéciale Markdown Extra.\n"\
"\n"\
"\t1\tMarkdown standard\n"\
"\t2\tMarkdown Extra\n"\
"\n"\
"Saisissez votre choix [1/2] (2 par défaut): ")
	read choix
	
	echo ""
	markdown=extra
	
	if [[ $choix == 1 ]]; then
		markdown=markdown
		echo $(gettext "Le langage Markdown standard sera ajouté.")
	else
		echo $(gettext "Le langage Markdown Extra sera ajouté.")
	fi
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo $(gettext "Étape 3: copie des fichiers")
	echo $normal
	
	# Création des répertoires s'ils n'existent pas déjà.
	mkdir -p $cheminLanguageSpecs
	mkdir -p $cheminPlugins
	mkdir -p $cheminSnippets
	mkdir -p $cheminStyles
	
	# Copie des fichiers.
	
	if [[ $markdown == "extra" ]]; then
		cp language-specs/markdown-extra.lang $cheminLanguageSpecs
		cp snippets/markdown-extra.xml $cheminSnippets
	else
		cp language-specs/markdown.lang $cheminLanguageSpecs
		cp snippets/markdown.xml $cheminSnippets
	fi
	
	if [[ $greffonEstInstallable == 1 ]]; then
		cp -r plugins/* $cheminPlugins
		
		if [[ $markdown == "markdown" ]]; then
			# Mise à jour de la configuration.
			sed -i "s/^\(version=\).*$/\1markdown/" $cheminPluginsMarkdownPreview/config.ini
		fi
		
		mkdir -p $cheminPythonSitePackages
		mv $cheminPluginsMarkdownPreview/markdown $cheminPythonSitePackages
		rm $cheminPluginsMarkdownPreview/locale/markdown-preview.pot
		find $cheminPluginsMarkdownPreview/locale/ -name '*.po' -exec rm -f {} \;
	fi
	
	cp styles/classic-markdown.xml $cheminStyles
	
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo $(gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo $normal
	
	exit 0
elif [[ $1 == "desinstaller" || $1 == "uninstall" ]]; then
	echo $gras
	echo "############################################################"
	echo "##"
	echo "## " $(gettext "Désinstallation de gedit-markdown")
	echo "##"
	echo "############################################################"
	
	echo ""
	echo $(gettext "Étape 1: suppression des fichiers")
	echo $normal
	
	# Suppression des fichiers.
	for i in "${fichiersAsupprimer[@]}"; do
		rm -f $i
	done
	
	# Suppression des dossiers.
	rm -rf $cheminPluginsMarkdownPreview
	rm -rf $cheminPythonSitePackages/markdown
	
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo $(gettext "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo $normal
	
	exit 0
else
	echo $gras
	echo $(gettext "Usage: ") "$0 [installer | installer extra | desinstaller]"
	echo $normal
	
	exit 1
fi

