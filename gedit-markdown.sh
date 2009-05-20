#!/bin/bash

# Le fichier gedit-markdown.sh fait partie de gedit-markdown.
# Auteur: Jean-Philippe Fleury <contact@jpfleury.net>
# Copyright © Jean-Philippe Fleury, 2009.

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

# Localisation
export TEXTDOMAINDIR=`dirname "$0"`/locale
export TEXTDOMAIN=gedit-markdown
. gettext.sh

# Variables
rep_language_specs=~/.local/share/gtksourceview-2.0/language-specs
rep_mime=~/.local/share/mime
rep_mime_packages=~/.local/share/mime/packages
rep_plugins=~/.gnome2/gedit/plugins
rep_snippets=~/.gnome2/gedit/snippets
ficPrecompil=( "$rep_plugins/markdown.pyc" "$rep_plugins/markdownpreview.pyc" )
ficSupp=( "${ficPrecompil[@]}" "$rep_language_specs/markdown.lang" "$rep_mime_packages/x-markdown.xml" "$rep_plugins/markdown.py" "$rep_plugins/markdownpreview.gedit-plugin" "$rep_plugins/markdownpreview.py" "$rep_snippets/markdown.xml" )
# Fin des variables

redemarrer_nautilus ()
{
	echo -en $(gettext ""\
"Nautilus doit être redémarré pour que les modifications apportées à la base\n"\
"de données des types MIME soient prises en compte. NOTE: les fenêtres ou\n"\
"onglets de Nautilus déjà ouverts seront perdus.\n"\
"\n"\
"\t1 Redémarrer Nautilus maintenant.\n"\
"\t2 Ne pas redémarrer Nautilus maintenant et attendre le prochain\n"\
"\tredémarrage de la session ou de l'ordinateur.\n"\
"\n"\
"Saisissez votre choix [1/2] (2 par défaut):")
	echo -n " "
	read choix
	
	echo ""
	if [[ $choix == 1 ]]; then
		echo $(gettext "Redémarrage de Nautilus")
		killall nautilus
		nautilus &> /tmp/gedit-markdown_redemarrer_nautilus.log &
		sleep 4
	
	else
		echo -e $(gettext "Nautilus ne sera pas redémarré maintenant (ceci ne vous\n"\
"empêche pas d'utiliser déjà Markdown dans gedit s'il s'agit d'une\n"\
"installation de gedit-markdown).")
	fi
}

cd `dirname "$0"`

if [[ $1 == "installer" ]]; then
	echo -en "\033[1m"
	echo -en "#########################\n##\n## "
	echo $(gettext "Installation de gedit-markdown")
	echo -e "##\n#########################\n"
	echo -n $(gettext "Étape 1")
	echo -n ": "
	echo $(gettext "Copie des fichiers")
	echo -en "\033[22m"
	
	# Création des répertoires s'ils n'existent pas déjà
	mkdir -p $rep_language_specs
	mkdir -p $rep_mime_packages
	mkdir -p $rep_plugins
	mkdir -p $rep_snippets
	
	# Suppression des fichiers python précompilés
	for i in "${ficPrecompil[@]}"; do
		if [ -f $i ]; then
			rm $i
		fi
	done
	
	# Copie des fichiers
	cp -a language-specs/* $rep_language_specs
	cp -a mime-packages/* $rep_mime_packages
	cp -a plugins/* $rep_plugins
	cp -a snippets/* $rep_snippets
	
	echo -en "\033[1m"
	echo ""
	echo -n $(gettext "Étape 2")
	echo -n ": "
	echo $(gettext "Mise à jour de la base de données MIME")
	echo -en "\033[22m"
	# Mise à jour de la base de données MIME
	update-mime-database $rep_mime
	redemarrer_nautilus
	
	echo -en "\033[1m"
	echo ""
	echo $(gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo -en "\033[22m"
	exit 0

elif [[ $1 == "desinstaller" ]]; then
	echo -en "\033[1m"
	echo -en "#########################\n##\n## "
	echo $(gettext "Désinstallation de gedit-markdown")
	echo -e "##\n#########################\n"
	echo -n $(gettext "Étape 1")
	echo -n ": "
	echo $(gettext "Suppression des fichiers")
	echo -en "\033[22m"
	# Suppression des fichiers
	for i in "${ficSupp[@]}"; do
		if [ -f $i ]; then
			rm $i
		fi
	done
	
	echo -en "\033[1m"
	echo ""
	echo -n $(gettext "Étape 2")
	echo -n ": "
	echo $(gettext "Mise à jour de la base de données MIME")
	echo -en "\033[22m"
	# Mise à jour de la base de données MIME
	update-mime-database $rep_mime
	redemarrer_nautilus
	
	echo -en "\033[1m"
	echo ""
	echo $(gettext "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert.")
	echo -en "\033[22m"
	exit 0

else
	echo -en "\033[1m"
	echo -n $(gettext "Usage")
	echo ": $0 [installer | desinstaller]"
	echo -en "\033[22m"
	exit 1
fi

