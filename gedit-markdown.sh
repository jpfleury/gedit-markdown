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
# ni d'ADÉQUATION À UN OBJECTIF PARTICULIER. Consultez la Licence Générale
# Publique GNU pour plus de détails.

# Vous devriez avoir reçu une copie de la Licence Générale Publique GNU avec
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
	gettext "Nautilus doit être redémarré pour que les modifications apportées à la base de données des types MIME soient prises en compte. NOTE: les fenêtres ou onglets de Nautilus déjà ouverts seront perdus.\\n\\n1 Redémarrer Nautilus maintenant.\\n2 Ne pas redémarrer Nautilus maintenant et attendre le prochain redémarrage de ma session ou de l'ordinateur.\\n\\nSaisir votre choix [1/2] (2 par défaut): "; echo -en
	read choix
	
	if [[ $choix == 1 ]]; then
		gettext "Redémarrage de Nautilus\\n"; echo -e
		killall nautilus
		nautilus &> /tmp/gedit-markdown_redemarrer_nautilus.log &
		sleep 2
	
	else
		gettext "Nautilus ne sera pas redémarré maintenant (ceci ne vous empêche pas d'utiliser déjà Markdown dans gedit s'il s'agit d'une installation de gedit-markdown).\\n"; echo -e
	fi
}

cd `dirname "$0"`

if [[ $1 == "installer" ]]; then
	gettext "Copie des fichiers"; echo
	
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
	
	gettext "Mise à jour de la base de données MIME"; echo
	# Mise à jour de la base de données MIME
	update-mime-database $rep_mime
	redemarrer_nautilus
	
	gettext "Installation terminée. Veuillez redémarrer gedit s'il est ouvert."; echo
	exit 0

elif [[ $1 == "desinstaller" ]]; then
	gettext "Suppression des fichiers"; echo
	# Suppression des fichiers
	for i in "${ficSupp[@]}"; do
		if [ -f $i ]; then
			rm $i
		fi
	done
	
	gettext "Mise à jour de la base de données MIME"; echo
	# Mise à jour de la base de données MIME
	update-mime-database $rep_mime
	redemarrer_nautilus
	
	gettext "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert."; echo
	exit 0

else
	eval_gettext "Usage: "; echo -n
	echo "$0 [installer | desinstaller]"
	exit 1
fi

