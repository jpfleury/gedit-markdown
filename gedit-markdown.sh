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
cheminSnippets=~/.gnome2/gedit/snippets
fichiersAsupprimer=( "$cheminLanguageSpecs/markdown.lang" "$cheminMimePackages/x-markdown.xml" "$cheminPlugins/markdown-preview.gedit-plugin" "$cheminSnippets/markdown.xml" )

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

# Début du script.

cd `dirname "$0"`

if [[ $1 == "installer" || $1 == "install" ]]; then
	echo -e "\033[1m"
	echo -en "########################################\n##\n## "
	echo $(gettext "Installation de gedit-markdown")
	echo -e "##\n########################################\n"
	echo $(gettext "Étape 1: Copie des fichiers")
	echo -e "\033[22m"
	
	# Création des répertoires s'ils n'existent pas déjà.
	mkdir -p $cheminLanguageSpecs
	mkdir -p $cheminMimePackages
	mkdir -p $cheminPlugins
	mkdir -p $cheminSnippets
	
	# Copie des fichiers.
	cp language-specs/markdown.lang $cheminLanguageSpecs
	cp mime-packages/x-markdown.xml $cheminMimePackages
	cp -r plugins/* $cheminPlugins
	rm $cheminPluginsMarkdownPreview/locale/markdown-preview.pot
	find $cheminPluginsMarkdownPreview/locale/ -name '*.po' -exec rm -f {} \;
	cp snippets/markdown.xml $cheminSnippets
	
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
	echo $(gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo -e "\033[22m"
	
	exit 0
elif [[ $1 == "desinstaller" || $1 == "uninstall" ]]; then
	echo -e "\033[1m"
	echo -en "########################################\n##\n## "
	echo $(gettext "Désinstallation de gedit-markdown")
	echo -e "##\n########################################\n"
	echo $(gettext "Étape 1: Suppression des fichiers")
	echo -e "\033[22m"
	
	# Suppression des fichiers.
	for i in "${fichiersAsupprimer[@]}"; do
		if [ -f $i ]; then
			rm $i
		fi
	done
	
	# Suppression du sous-dossier du greffon.
	rm -rf $cheminPluginsMarkdownPreview
	
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
	echo $(gettext "Usage: ") "$0 [installer | desinstaller]"
	echo -en "\033[22m"
	
	exit 1
fi

