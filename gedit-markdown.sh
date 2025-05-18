#!/bin/bash

# This file is part of gedit-markdown.
# Author: Jean-Philippe Fleury <https://github.com/jpfleury>
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

################################################################################
## @title Functions
################################################################################

# Note that if a directory doesn't have read permissions, the function can't
# test if it contains files.
is_empty() {
	if [[ -d $1 && -r $1 ]]; then
		shopt -s nullglob dotglob
		declare -a files
		files=("$1"/*)
		shopt -u nullglob dotglob

		if [[ ${#files[@]} == 0 ]]; then
			return 0
		fi
	fi

	return 1
}

remove_empty_dirs() {
	local dir
	
	# --------------------
	
	for dir in "$@"; do
		while is_empty "$dir"; do
			rmdir -v "$dir"
			
			dir=$(dirname "$dir")
		done
	done
}

remove_plugin() {
	local file
	declare -a files_to_remove
	declare -a empty_dirs_to_remove
	
	# --------------------
	
	# Remove files
	##############
	
	files_to_remove=(
		"$PATH_PLUGIN/markdown-preview.gedit-plugin"
		"$PATH_SNIPPETS/markdown.xml"
		"$PATH_TOOLS/export-to-html"
		"$PATH_TOOLS/export-to-pdf"
	)
	
	for file in "${files_to_remove[@]}"; do
		if [[ -f $file ]]; then
			rm -v "$file"
		fi
	done

	# Remove directories
	####################
	
	empty_dirs_to_remove=(
		"$PATH_CONFIG"
		"$PATH_PLUGIN"
		"$PATH_MARKDOWN_PREVIEW_PLUGIN"
		"$PATH_SNIPPETS"
		"$PATH_TOOLS"
	)
	
	if [[ -d $PATH_MARKDOWN_PREVIEW_PLUGIN ]]; then
		rm -rv "$PATH_MARKDOWN_PREVIEW_PLUGIN"
	fi
	
	remove_empty_dirs "${empty_dirs_to_remove[@]}"
}

################################################################################
## @title Constants
################################################################################

PATH_PLUGIN=${XDG_DATA_HOME:-$HOME/.local/share}/gedit/plugins
PATH_MARKDOWN_PREVIEW_PLUGIN=$PATH_PLUGIN/markdown-preview

PATH_CONFIG_GEDIT=${XDG_CONFIG_HOME:-$HOME/.config}

PATH_CONFIG=$PATH_CONFIG_GEDIT/markdown-preview
PATH_SNIPPETS=$PATH_CONFIG_GEDIT/snippets
PATH_TOOLS=$PATH_CONFIG_GEDIT/tools

declare -r PATH_PLUGIN PATH_MARKDOWN_PREVIEW_PLUGIN PATH_CONFIG_GEDIT
declare -r PATH_CONFIG PATH_SNIPPETS PATH_TOOLS

################################################################################
## @title Script
################################################################################

cd "$(dirname "$0")" || { echo >&2 "Can't access $0"; exit 1; }

if [[ $1 == install ]]; then
	echo "# gedit-markdown install"
	echo "########################"
	echo ""
	
	# Just in case it's an update (not first install)
	remove_plugin

	# Configuration
	mkdir -pv "$PATH_CONFIG"
	cp -rnv config/* "$PATH_CONFIG"

	# Code snippets
	mkdir -pv "$PATH_SNIPPETS"
	cp -v snippets/markdown.xml "$PATH_SNIPPETS"

	# External tools
	mkdir -pv "$PATH_TOOLS"
	cp -v tools/export-to-html "$PATH_TOOLS"
	chmod +x "$PATH_TOOLS/export-to-html"
	cp -v tools/export-to-pdf "$PATH_TOOLS"
	chmod +x "$PATH_TOOLS/export-to-pdf"

	# Markdown Preview plugin
	mkdir -pv "$PATH_PLUGIN"
	cp -rv plugins/markdown-preview/* "$PATH_PLUGIN"
	rm -v "$PATH_MARKDOWN_PREVIEW_PLUGIN/locale/markdown-preview.pot"
	find "$PATH_MARKDOWN_PREVIEW_PLUGIN/locale/" -name "*.po" -exec rm -v {} \;

	echo "Installation successful. Please restart gedit (if it's already running)."

	exit 0
elif [[ $1 == uninstall ]]; then
	echo "# gedit-markdown uninstall"
	echo "##########################"
	echo ""
	
	remove_plugin
	
	echo "Uninstallation successful. Please restart gedit (if it's already running)."

	exit 0
else
	echo "Usage: $0 [install|uninstall]"

	exit 1
fi
