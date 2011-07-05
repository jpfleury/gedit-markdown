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

########################################################################
##
## Localisation.
##
########################################################################

export TEXTDOMAINDIR=./locale
export TEXTDOMAIN=gedit-markdown

if [[ ${LANG:0:2} == "fr" ]]; then
	export LANGUAGE=fr
fi

. gettext.sh

########################################################################
##
## Fonctions.
##
########################################################################

supprimerDossiersVides()
{
	dossier=$1
	
	while [[ -d $dossier && -z $(ls -A $dossier 2> /dev/null) ]]; do
		rmdir -v $dossier
		dossier=$(dirname "$dossier")
	done
}

supprimerGreffon()
{
	# Suppression des fichiers.
	
	for i in "${anciensFichiersAsupprimer[@]}"; do
		rm -fv $i
	done
	
	for i in "${fichiersAsupprimer[@]}"; do
		rm -fv $i
	done
	
	# Suppression des dossiers.
	
	rm -rfv $cheminPluginsMarkdownPreview
	
	if [[ -n $cheminPythonSitePackages ]]; then
		rm -rfv $cheminPythonSitePackages/markdown
		supprimerDossiersVides $cheminPythonSitePackages
	fi
	
	if [[ -n $ancienCheminPythonSitePackages ]]; then
		rm -rfv $ancienCheminPythonSitePackages/markdown
		supprimerDossiersVides $ancienCheminPythonSitePackages
	fi
	
	supprimerDossiersVides $cheminConfig
	supprimerDossiersVides $cheminLanguageSpecs
	supprimerDossiersVides $cheminPlugins
	supprimerDossiersVides $cheminPluginsMarkdownPreview
	supprimerDossiersVides $cheminSnippets
	supprimerDossiersVides $cheminStyles
	supprimerDossiersVides $cheminTools
	# Anciennes versions.
	supprimerDossiersVides $cheminInvalideGeditSnippets
	supprimerDossiersVides $cheminInvalideGeditTools
	supprimerDossiersVides $cheminMimePackages
}

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

if [[ -n $(which gedit) ]]; then
	versionGedit=$(gedit --version | cut -d ' ' -f 4)
fi

####################################
## Chemins.
####################################

if [[ ${versionGedit:0:1} == "3" ]]; then
	# gedit 3.
	cheminGeditMarkdownPluginsGedit=plugins/gedit3
	cheminLanguageSpecs=~/.local/share/gtksourceview-3.0/language-specs
	cheminSystemeLanguageSpecs=/usr/share/gtksourceview-3.0/language-specs
	cheminPlugins=~/.local/share/gedit/plugins
	cheminPluginsMarkdownPreview=~/.local/share/gedit/plugins/markdown-preview
	cheminSnippets=~/.config/gedit/snippets
	cheminSystemeSnippets=/usr/share/gedit/plugins/snippets
	cheminStyles=~/.local/share/gtksourceview-3.0/styles
	cheminTools=~/.config/gedit/tools
else
	# gedit 2.
	cheminGeditMarkdownPluginsGedit=plugins/gedit2
	cheminLanguageSpecs=~/.local/share/gtksourceview-2.0/language-specs
	cheminSystemeLanguageSpecs=/usr/share/gtksourceview-2.0/language-specs
	cheminPlugins=~/.gnome2/gedit/plugins
	cheminPluginsMarkdownPreview=~/.gnome2/gedit/plugins/markdown-preview
	cheminSnippets=~/.gnome2/gedit/snippets
	cheminSystemeSnippets=/usr/share/gedit-2/plugins/snippets
	cheminStyles=~/.local/share/gtksourceview-2.0/styles
	cheminTools=~/.gnome2/gedit/tools
fi

cheminConfig=~/.config
cheminFichierConfig=$cheminConfig/gedit-markdown.ini

if [[ -f $cheminFichierConfig ]]; then
	ancienCheminPythonSitePackages=$(sed -n "s/^pythonSitePackages=\(.*\)$/\1/p" < $cheminFichierConfig)
fi

####################################
## Classe `no-spell-check` dans le fichier de langue.
####################################

# Le fichier de langue HTML est utilisé comme référence pour vérifier si la version installée de GtkSourceView supporte la classe `no-spell-check` dans les fichiers de langue.
cheminHtmlLang=$cheminSystemeLanguageSpecs/html.lang
supportClasseNoSpellCheck=1

if [[ -f $cheminHtmlLang && -z $(grep ' class="no-spell-check"' $cheminHtmlLang) ]]; then
	supportClasseNoSpellCheck=0
fi

####################################
## Version de Python.
####################################

bonneVersionPython=1

if [[ -z $(which python) ]]; then
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

cheminAncienFichierConfig=~/.gedit-markdown.ini
cheminMimePackages=~/.local/share/mime/packages

# Dossiers invalides utilisés un certain temps pour gedit 3.
cheminInvalideGeditSnippets=~/.local/share/gedit/snippets
cheminInvalideGeditTools=~/.local/share/gedit/tools

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

cd $(dirname "$0")

if [[ $1 == "installer" || $1 == "install" ]]; then
	echo $gras
	echo "############################################################"
	echo "##"
	echo "##" $(gettext "Installation de gedit-markdown")
	echo "##"
	echo "############################################################"
	
	echo ""
	echo "##" $(gettext "Première étape: vérification des dépendances")
	echo $normal
	
	echo "- gedit: $versionGedit"
	echo "- Python: $versionPython"
	echo ""
	
	if [[ -z $versionGedit ]]; then
		echo $(gettext "Veuillez installer gedit avant de lancer le script d'installation de gedit-markdown.")
		echo ""
		exit 1
	fi
	
	if [[ $supportClasseNoSpellCheck == 0 ]]; then
		echo -e $(gettext ""\
"La vérification orthographique ne peut pas être désactivée dans la coloration\n"\
"syntaxique pour les contextes non pertinents (par exemple dans les adresses URL),\n"\
"car cette fonctionnalité dépend de GtkSourceView >= 2.10.")
		echo ""
	fi
	
	if [[ $bonneVersionPython == 0 ]]; then
		echo -e $(gettext ""\
"Le greffon «Aperçu Markdown» ne sera pas installé, car il dépend de Python >= 2.6.")
		echo ""
	fi
	
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo "##" $(gettext "Étape suivante: choix de la syntaxe Markdown à installer")
	echo $normal
	
	echo -e $(gettext ""\
"gedit-markdown peut ajouter le support du langage Markdown standard ou de la\n"\
"version spéciale Markdown Extra.\n"\
"\n"\
"\t1\tMarkdown standard\n"\
"\t2\tMarkdown Extra\n")
	gettext "Saisissez votre choix [1/2] (2 par défaut): "
	read choix
	
	echo ""
	markdown=extra
	
	if [[ $choix == 1 ]]; then
		markdown=standard
		echo $(gettext "Le langage Markdown standard sera ajouté.")
	else
		echo $(gettext "Le langage Markdown Extra sera ajouté.")
	fi
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	if [[ $bonneVersionPython == 1 ]]; then
		echo $gras
		echo "##" $(gettext "Étape suivante: choix de l'emplacement de l'aperçu Markdown")
		echo $normal
	
		echo -e $(gettext ""\
"L'aperçu Markdown peut être placé dans un des deux panneaux de gedit.\n"\
"\n"\
"\t1\tPanneau latéral\n"\
"\t2\tPanneau inférieur\n")
		gettext "Saisissez votre choix [1/2] (2 par défaut): "
		read choix
	
		echo ""
		panneau=bottom
	
		if [[ $choix == 1 ]]; then
			panneau=side
			echo $(gettext "L'aperçu Markdown se trouvera dans le panneau latéral.")
		else
			echo $(gettext "L'aperçu Markdown se trouvera dans le panneau inférieur.")
		fi
	
		echo ""
		echo $(gettext "Étape terminée.")
	fi
	
	echo $gras
	echo "##" $(gettext "Étape suivante: copie des fichiers")
	echo $normal
	
	# Au cas où il s'agit d'une mise à jour et non d'une première installation.
	supprimerGreffon
	
	# Création des répertoires s'ils n'existent pas déjà.
	mkdir -pv $cheminConfig
	mkdir -pv $cheminLanguageSpecs
	mkdir -pv $cheminPlugins
	mkdir -pv $cheminSnippets
	mkdir -pv $cheminStyles
	
	# Copie des fichiers.
	
	if [[ ! -e $cheminFichierConfig ]]; then
		cp -v config/gedit-markdown.ini $cheminFichierConfig
	fi
	
	if [[ $markdown == "standard" ]]; then
		if [[ ! -e "$cheminSystemeLanguageSpecs/markdown.lang" ]]; then
			cp -v language-specs/markdown.lang $cheminLanguageSpecs
			cheminLanguageSpecsMarkdownLang=$cheminLanguageSpecs/markdown.lang
		fi
		
		if [[ ! -e "$cheminSystemeSnippets/markdown.xml" ]]; then
			cp -v snippets/markdown.xml $cheminSnippets
		fi
		
		# Mise à jour de la configuration.
		if [[ -n $(grep "^version=" $cheminFichierConfig) ]]; then
			sed -i "s/^\(version=\).*$/\1standard/" $cheminFichierConfig
		else
			sed -i "s/^\(\[markdown-preview\]\)$/\1\nversion=standard/" $cheminFichierConfig
		fi
	else
		cp -v language-specs/markdown-extra.lang $cheminLanguageSpecs
		cheminLanguageSpecsMarkdownLang=$cheminLanguageSpecs/markdown-extra.lang
		cp -v snippets/markdown-extra.xml $cheminSnippets
	fi
	
	# Compatibilité avec GtkSourceView < 2.10.
	if [[ -f $cheminLanguageSpecsMarkdownLang ]]; then
		sed -i 's/ class="no-spell-check"//g' $cheminLanguageSpecsMarkdownLang
	fi
	
	if [[ $bonneVersionPython == 1 ]]; then
		# Python-Markdown.
		
		mkdir -pv $cheminPythonSitePackages
		cp -rv python-markdown $cheminPythonSitePackages/markdown
		
		# Mise à jour de la configuration.
		if [[ -n $(grep "^pythonSitePackages=" $cheminFichierConfig) ]]; then
			sed -i "s|^\(pythonSitePackages=\).*$|\1$cheminPythonSitePackages|" $cheminFichierConfig
		else
			sed -i "s|^\(\[markdown-preview\]\)$|\1\npythonSitePackages=$cheminPythonSitePackages|" $cheminFichierConfig
		fi
		
		# Outil externe.
		mkdir -pv $cheminTools
		cp -v tools/export-to-html $cheminTools
		
		# Greffon «Aperçu Markdown».
		
		cp -rv $cheminGeditMarkdownPluginsGedit/* $cheminPlugins
		rm -v $cheminPluginsMarkdownPreview/locale/markdown-preview.pot
		find $cheminPluginsMarkdownPreview/locale/ -name '*.po' -exec rm -fv {} \;
		
		if [[ $panneau == "side" ]]; then
			# Mise à jour de la configuration.
			if [[ -n $(grep "^panel=" $cheminFichierConfig) ]]; then
				sed -i "s/^\(panel=\).*$/\1side/" $cheminFichierConfig
			else
				sed -i "s/^\(\[markdown-preview\]\)$/\1\npanel=side/" $cheminFichierConfig
			fi
		fi
	fi
	
	cp -v styles/classic-markdown.xml $cheminStyles
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo $(gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo $normal
	
	exit 0
elif [[ $1 == "desinstaller" || $1 == "uninstall" ]]; then
	echo $gras
	echo "############################################################"
	echo "##"
	echo "##" $(gettext "Désinstallation de gedit-markdown")
	echo "##"
	echo "############################################################"
	
	echo ""
	echo "##" $(gettext "Première étape: suppression des fichiers")
	echo $normal
	
	supprimerGreffon
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	echo $gras
	echo $(gettext "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo $normal
	
	exit 0
else
	echo $gras
	echo $(gettext "Usage: ") "$0 [installer | desinstaller]"
	echo $normal
	
	exit 1
fi

