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

# Variables.
cheminLanguageSpecs=~/.local/share/gtksourceview-2.0/language-specs
cheminMime=~/.local/share/mime
cheminMimePackages=~/.local/share/mime/packages
cheminPlugins=~/.gnome2/gedit/plugins
cheminPluginsMarkdownPreview=~/.gnome2/gedit/plugins/markdown-preview
cheminPythonSitePackages=$(python -m site --user-site)
cheminSnippets=~/.gnome2/gedit/snippets
fichiersAsupprimer=( "$cheminLanguageSpecs/markdown.lang" "$cheminLanguageSpecs/markdown-extra.lang" "$cheminMimePackages/x-markdown.xml" "$cheminPlugins/markdown-preview.gedit-plugin" "$cheminSnippets/markdown.xml" "$cheminSnippets/markdown-extra.xml" )

# Fonctions.

redemarrerNautilus()
{
	echo -en $(gettext ""\
"Nautilus doit être redémarré pour que les modifications apportées à la base\n"\
"de données partagée MIME-Info soient prises en compte.\n"\
"\n"\
"\t1\tRedémarrer Nautilus maintenant (les fenêtres ou les onglets déjà ouverts\n"\
"\t\tde Nautilus seront perdus).\n"\
"\t2\tNe pas redémarrer Nautilus maintenant et attendre le prochain\n"\
"\t\tredémarrage de la session ou de l'ordinateur.\n"\
"\n"\
"Saisissez votre choix [1/2] (2 par défaut): ")
	read choix
	
	echo ""
	
	if [[ $choix == 1 ]]; then
		echo $(gettext "Redémarrage de Nautilus.")
		killall nautilus
		nautilus &> /tmp/gedit-markdown.log &
		sleep 5
	else
		echo $(gettext "Nautilus ne sera pas redémarré maintenant.")
		
		if [[ $1 == "installer" ]]; then
			echo $(gettext "Vous pouvez quand même utiliser dès maintenant Markdown dans gedit.")
		fi
	fi
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

# Début du script.

cd `dirname "$0"`

markdown=markdown

if [[ $2 == "extra" ]]; then
	markdown=extra
fi

if [[ $1 == "installer" || $1 == "install" ]]; then
	echo -e "\033[1m"
	echo -en "############################################################\n##\n## "
	
	if [[ $markdown == "extra" ]]; then
		echo $(gettext "Installation de gedit-markdown (version Markdown Extra)")
	else
		echo $(gettext "Installation de gedit-markdown (version Markdown)")
	fi
	
	echo -e "##\n############################################################\n"
	
	echo -e "\033[1m"
	echo $(gettext "Étape 1: Vérification des dépendances")
	echo -e "\033[22m"
	
	versionPython=0
	erreurPython=0
	
	if [ -z $(which python) ]; then
		erreurPython=1
	else
		versionPython=$(python -c 'import sys; print(sys.version[:3])')
		vercomp $versionPython "2.6"
		
		if [[ $? == 2 ]]; then
			erreurPython=1
		fi
	fi
	
	if [[ $erreurPython == 1 ]]; then
		echo $(gettext "Le greffon «Markdown Preview» ne sera pas installé, car il nécessite Python 2.6 ou plus récent.")
	fi
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	echo $(gettext "Étape 2: Copie des fichiers")
	echo -e "\033[22m"
	
	# Création des répertoires s'ils n'existent pas déjà.
	mkdir -p $cheminLanguageSpecs
	mkdir -p $cheminMimePackages
	mkdir -p $cheminPlugins
	mkdir -p $cheminPythonSitePackages
	mkdir -p $cheminSnippets
	
	# Copie des fichiers.
	
	if [[ $markdown == "extra" ]]; then
		cp language-specs/markdown-extra.lang $cheminLanguageSpecs
		cp snippets/markdown-extra.xml $cheminSnippets
	else
		cp language-specs/markdown.lang $cheminLanguageSpecs
		cp snippets/markdown.xml $cheminSnippets
	fi
	
	cp mime-packages/x-markdown.xml $cheminMimePackages
	
	if [[ $erreurPython == 0 ]]; then
		cp -r plugins/* $cheminPlugins
		
		if [[ $markdown == "extra" ]]; then
			# Mise à jour de la configuration.
			sed -i "s/^\(version=\).*$/\1extra/" $cheminPluginsMarkdownPreview/config.ini
		fi
		
		mv $cheminPluginsMarkdownPreview/markdown $cheminPythonSitePackages
		rm $cheminPluginsMarkdownPreview/locale/markdown-preview.pot
		find $cheminPluginsMarkdownPreview/locale/ -name '*.po' -exec rm -f {} \;
	fi
	
	echo $(gettext "Étape terminée.")
	
	echo -e "\033[1m"
	echo $(gettext "Étape 3: Mise à jour de la base de données MIME")
	echo -e "\033[22m"
	
	# Mise à jour de la base de données MIME.
	update-mime-database $cheminMime
	redemarrerNautilus $1
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	echo -e "\033[1m"
	echo $(gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo -e "\033[22m"
	
	exit 0
elif [[ $1 == "desinstaller" || $1 == "uninstall" ]]; then
	echo -e "\033[1m"
	echo -en "############################################################\n##\n## "
	echo $(gettext "Désinstallation de gedit-markdown")
	echo -e "##\n############################################################\n"
	
	echo $(gettext "Étape 1: Suppression des fichiers")
	echo -e "\033[22m"
	
	# Suppression des fichiers.
	for i in "${fichiersAsupprimer[@]}"; do
		rm -f $i
	done
	
	# Suppression des dossiers.
	rm -rf $cheminPluginsMarkdownPreview
	rm -rf $cheminPythonSitePackages/markdown
	
	echo $(gettext "Étape terminée.")
	
	echo -e "\033[1m"
	echo $(gettext "Étape 2: Mise à jour de la base de données MIME")
	echo -e "\033[22m"
	
	# Mise à jour de la base de données MIME.
	update-mime-database $cheminMime
	redemarrerNautilus $1
	
	echo ""
	echo $(gettext "Étape terminée.")
	
	echo -e "\033[1m"
	echo $(gettext "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo -e "\033[22m"
	
	exit 0
else
	echo -en "\033[1m"
	echo $(gettext "Usage: ") "$0 [installer | installer extra | desinstaller]"
	echo -en "\033[22m"
	
	exit 1
fi

