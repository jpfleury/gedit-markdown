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
	echo -en "Nautilus doit être redémarré pour que les modifications apportées à la base de données des types MIME soient prises en compte. NOTE: les fenêtres ou onglets de Nautilus déjà ouverts seront perdus.\n\n1 Redémarrer Nautilus maintenant.\n2 Ne pas redémarrer Nautilus maintenant et attendre le prochain redémarrage de ma session ou de l'ordinateur.\n\nSaisir votre choix [1/2] (2 par défaut): "
	read choix
	
	if [[ $choix == 1 ]]; then
		echo "Redémarrage de Nautilus"
		killall nautilus && nautilus
	
	else
		echo "Nautilus ne sera pas redémarré maintenant. Ceci ne vous empêche pas d'utiliser déjà Markdown dans gedit s'il s'agit d'une installation."
	fi
}

cd `dirname "$0"`

if [[ $1 == "installer" ]]; then
	echo "Copie des fichiers"
	
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
	
	echo "Mise à jour de la base de données MIME"
	# Mise à jour de la base de données MIME
	update-mime-database $rep_mime
	redemarrer_nautilus
	
	echo "Installation terminée. Veuillez redémarrer gedit s'il est ouvert."
	exit 0

elif [[ $1 == "desinstaller" ]]; then
	echo "Suppression des fichiers"
	# Suppression des fichiers
	for i in "${ficSupp[@]}"; do
		if [ -f $i ]; then
			rm $i
		fi
	done
	
	echo "Mise à jour de la base de données MIME"
	# Mise à jour de la base de données MIME
	update-mime-database $rep_mime
	redemarrer_nautilus
	
	echo "Désinstallation terminée. Veuillez redémarrer gedit s'il est ouvert."
	exit 0

else
	echo -e "Usage: $0 [installer | desinstaller]"
	exit 1
fi

