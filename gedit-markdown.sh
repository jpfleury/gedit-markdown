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
## @title Setup
################################################################################

set -euo pipefail
trap 'echo "Error on line $LINENO: $BASH_COMMAND" >&2' ERR
trap 'exit 1' INT TERM

################################################################################
## @title Functions
################################################################################

is_empty_dir() {
	local dir=$1

	# --------------------

	# Return false if:
	# - not a directory, or
	# - not readable (we can't test its contents), or
	# - is a symlink
	if [[ ! -d $dir || ! -r $dir || -L $dir ]]; then
		return 1
	fi

	# Subshell to avoid changing the global shopt state
	if (
		shopt -s nullglob dotglob
		declare -a files
		files=("$dir"/*)
		(( ${#files[@]} == 0 ))
	); then
		return 0
	fi

	return 1
}

remove_empty_dirs() {
	local dir parent

	# --------------------

	for dir in "$@"; do
		while is_empty_dir "$dir"; do
			rmdir -v "$dir" || break

			parent=$(dirname -- "$dir")

			[[ $parent == "$dir" || $parent == / ]] && break

			dir=$parent
		done
	done
}

remove_plugin() {
	local file
	declare -a files_to_remove
	declare -a empty_dirs_to_remove

	# --------------------

	# Files
	#######

	files_to_remove=(
		"$PATH_SNIPPETS_GEDIT/markdown.xml"
		"$PATH_TOOLS_GEDIT/export-to-html"
		"$PATH_TOOLS_GEDIT/export-to-pdf"
		"$PATH_PLUGINS_GEDIT/markdown-preview.plugin"

		# Obsolete
		"$PATH_CONFIG_GEDIT/gedit-markdown.ini"
		"$PATH_PLUGINS_GEDIT/markdown-preview.gedit-plugin"
	)

	for file in "${files_to_remove[@]}"; do
		if [[ ! -e $file ]]; then
			echo "File not found: $file"

			continue
		fi

		if [[ ! -f $file || -L $file ]]; then
			echo "Ignoring file: $file"

			continue
		fi

		rm -v "$file"
	done

	# Directories
	#############

	empty_dirs_to_remove=(
		"$PATH_CONFIG"
		"$PATH_PLUGINS_GEDIT"
		"$PATH_PLUGIN_MARKDOWN_PREVIEW"
		"$PATH_SNIPPETS_GEDIT"
		"$PATH_TOOLS_GEDIT"
	)

	if [[ ! -e $PATH_CONFIG ]]; then
		echo "Directory not found: $PATH_CONFIG"
	elif [[ ! -d $PATH_CONFIG || -L $PATH_CONFIG ]]; then
		echo "Ignoring directory: $PATH_CONFIG"
	else
		rm -rv "$PATH_CONFIG"
	fi

	if [[ ! -e $PATH_PLUGIN_MARKDOWN_PREVIEW ]]; then
		echo "Directory not found: $PATH_PLUGIN_MARKDOWN_PREVIEW"
	elif [[ ! -d $PATH_PLUGIN_MARKDOWN_PREVIEW || -L $PATH_PLUGIN_MARKDOWN_PREVIEW ]]; then
		echo "Ignoring directory: $PATH_PLUGIN_MARKDOWN_PREVIEW"
	else
		rm -rv "$PATH_PLUGIN_MARKDOWN_PREVIEW"
	fi

	remove_empty_dirs "${empty_dirs_to_remove[@]}"
}

################################################################################
## @title Constants
################################################################################

# gedit
#######

PATH_CONFIG_GEDIT=${XDG_CONFIG_HOME:-$HOME/.config}/gedit
PATH_SNIPPETS_GEDIT=$PATH_CONFIG_GEDIT/snippets
PATH_TOOLS_GEDIT=$PATH_CONFIG_GEDIT/tools

PATH_DATA_GEDIT=${XDG_DATA_HOME:-$HOME/.local/share}/gedit
PATH_PLUGINS_GEDIT=$PATH_DATA_GEDIT/plugins

declare -r PATH_CONFIG_GEDIT PATH_SNIPPETS_GEDIT PATH_TOOLS_GEDIT
declare -r PATH_DATA_GEDIT PATH_PLUGINS_GEDIT

# gedit-markdown
################

PATH_CONFIG=$PATH_CONFIG_GEDIT/markdown-preview

PATH_PLUGIN_MARKDOWN_PREVIEW=$PATH_PLUGINS_GEDIT/markdown-preview

declare -r PATH_CONFIG PATH_PLUGIN_MARKDOWN_PREVIEW

################################################################################
## @title Arguments
################################################################################

action=${1:-}

################################################################################
## @title Script
################################################################################

cd "$(dirname "$0")" || { echo >&2 "Can't access $0"; exit 1; }

if [[ $action == install ]]; then
	echo "# gedit-markdown install"
	echo "########################"
	echo

	# In case this is an update
	###########################

	echo "Removing previous installation (if any)..."
	remove_plugin
	echo

	# Configuration
	###############

	echo "Proceeding with installation..."
	mkdir -pv "$PATH_CONFIG"
	cp -rv --update=none config/* "$PATH_CONFIG"

	# Code snippets
	###############

	mkdir -pv "$PATH_SNIPPETS_GEDIT"
	cp -v snippets/markdown.xml "$PATH_SNIPPETS_GEDIT"

	# External tools
	################

	mkdir -pv "$PATH_TOOLS_GEDIT"

	cp -v tools/export-to-html "$PATH_TOOLS_GEDIT"
	chmod +x "$PATH_TOOLS_GEDIT/export-to-html"

	cp -v tools/export-to-pdf "$PATH_TOOLS_GEDIT"
	chmod +x "$PATH_TOOLS_GEDIT/export-to-pdf"

	# Markdown Preview plugin
	#########################

	mkdir -pv "$PATH_PLUGINS_GEDIT"

	if [[ ! -L $PATH_PLUGINS_GEDIT/markdown-preview.plugin ]]; then
		cp -v plugins/markdown-preview/markdown-preview.plugin "$PATH_PLUGINS_GEDIT"
	fi

	mkdir -pv "$PATH_PLUGIN_MARKDOWN_PREVIEW"

	if [[ ! -L $PATH_PLUGIN_MARKDOWN_PREVIEW ]]; then
		cp -rv plugins/markdown-preview/markdown-preview/* "$PATH_PLUGIN_MARKDOWN_PREVIEW"

		# locale
		########

		rm -v "$PATH_PLUGIN_MARKDOWN_PREVIEW/locale/markdown-preview.pot"

		if command -v msgfmt >/dev/null 2>&1; then
			echo "Compiling .po files to .mo files..."

			find "$PATH_PLUGIN_MARKDOWN_PREVIEW/locale/" -name "*.po" -print0 | \
			while IFS= read -r -d '' po; do
				mo=${po%.*}.mo

				if msgfmt -o "$mo" "$po"; then
					echo "Compiled: $mo"
				else
					echo "Compilation failed: $mo"
				fi
			done
		else
			echo "msgfmt not found. Skipping .po compilation."
		fi

		find "$PATH_PLUGIN_MARKDOWN_PREVIEW/locale/" -name "*.po" -exec rm -v {} \;
	fi

	echo
	echo "Installation successful. Please restart gedit (if it's already running)."
	echo

	exit 0
elif [[ $action == uninstall ]]; then
	echo "# gedit-markdown uninstall"
	echo "##########################"
	echo

	remove_plugin

	echo
	echo "Uninstallation successful. Please restart gedit (if it's already running)."
	echo

	exit 0
else
	echo
	echo "Usage: $0 [install|uninstall]"
	echo

	exit 1
fi
