**Versions:**

- For gedit 2 and gedit 3.0 to 3.6, please refer to the [documentation of gedit-markdown v1](https://github.com/jpfleury/gedit-markdown/tree/v1#readme).
- For gedit 3.8 to 3.12, please refer to the [documentation of gedit-markdown v2](https://github.com/jpfleury/gedit-markdown/tree/v2#readme).
- For gedit 3.28 to 3.38, see the documentation below (gedit-markdown v3).

## Overview

gedit-markdown adds support for Markdown in gedit, the default Gnome text editor.

Specifically, it adds:

- Markdown *snippets*

- plugin *Markdown Preview* for gedit, displayed in the side panel or the bottom panel and previewing in HTML the current document or selection

- an *external tool* for exporting to HTML or PDF the current document or selection

<img src="https://raw.githubusercontent.com/jpfleury/gedit-markdown/master/doc/exemple1.png" width="684" height="779" alt="Default Markdown syntax highlighting in gedit." />

## Requirements

- gedit-markdown v3 supports gedit 3.8 and 3.10. It's shipped with an installer for GNU/Linux.

- The plugin *Markdown Preview* depends on the packages `python3-markdown` and `gir1.2-webkit2-4.0`.

## Installation (or update)

- [Download the archive of gedit-markdown v3.](https://github.com/jpfleury/gedit-markdown/archive/master.zip)

- Extract the archive.

- Open a terminal in the extracted folder.

- Run the installer in the terminal:

		./gedit-markdown.sh install

Markdown support will be added for the current user (so no need root privileges). The folder created by the extraction can be deleted after installation.

## Uninstallation

- Open a terminal in the extracted folder.

- Run the uninstaller in the terminal:

		./gedit-markdown.sh uninstall

## Usage

First of all, restart gedit if it's already running.

### Syntax highlighting

Syntax highlighting should automatically be activated for files recognized as Markdown files (extensions `.markdown`, `.md` or `.mkd`), otherwise choose it manually by going to *View > Highlight Mode > Markup* and selecting *Markdown*.

### Plugin *Markdown Preview*

To enable this plugin, go to *Edit > Preferences > Plugins* and check *Markdown Preview*.

Two items are added in the gedit menu *Tools*:

- *Update Markdown Preview*: displays in the side panel or in the bottom panel a preview in HTML of the current document or selection.

	Note: there are two other ways to update preview:
	
	  - with the keyboard shortcut *Ctrl+Alt+m* (can be changed in the configuration file);
	
	  - by right clicking on the preview area (side or bottom panel) and selecting the item *Update Preview*.

- *Toggle Markdown Preview visibility*: allows to display or hide the Markdown Preview panel tab.

	Note: the keyboard shortcut *Ctrl+Alt+v* (can be changed in the configuration file) can be used to do the same.

When right clicking on the preview area, a context menu appears and lists several options. Besides the default ones (previous page, next page, copy, etc.), we have:

- *Update Preview*: reloads in the side panel or in the bottom panel the preview in HTML of the current document or selection.

Local files will be followed in the preview area while global ones will be opened with your default web browser.

Here's a screenshot of the plugin when it's displayed in the bottom panel:

<img src="https://raw.githubusercontent.com/jpfleury/gedit-markdown/master/doc/exemple3.png" width="684" height="886" alt="Markdown Preview in the bottom panel of gedit." />

Now the same plugin displayed in the side panel (click to see the original image):

<a href="https://raw.githubusercontent.com/jpfleury/gedit-markdown/master/doc/exemple4-grand.png"><img src="https://raw.githubusercontent.com/jpfleury/gedit-markdown/master/doc/exemple4-petit.png" width="684" height="445" alt="Markdown Preview in the side panel of gedit." /></a>

Note that when the cursor passes over a link in the preview area, a tooltip displays the URL:

<img src="https://raw.githubusercontent.com/jpfleury/gedit-markdown/master/doc/exemple5.png" width="684" height="128" alt="Tooltip displaying URL when the cursor passes over a link." />

### Table of contents

When the Markdown extension `toc` is enabled (see _Configuration file_, default), add `[TOC]` to your Markdown source to generate a table of contents with clickable links.

### Snippets

To use Markdown snippets, activate the plugin *Snippets* in *Edit > Preferences > Plugins*. Then, go to *Tools > Manage Snippets...* to see the possibilities.

### Converters (external tools)

The following tools are included:

- Export to HTML
- Export to PDF

To use the external tool, activate the plugin *External Tools* in *Edit > Preferences > Plugins*. Then, go to *Tools > External Tools > Export to HTML* to access the tool. The keyboard shortcut *Ctrl+Alt+h* does the same. The code of the currently opened Markdown file or the selection will be converted in HTML/PDF, and the result will be put in a new document.

To edit the tool, go to *Tools > Manage External Tools...*.

### Configuration file

The configuration file of gedit-markdown is located at:

	$XDG_CONFIG_HOME/gedit/gedit-markdown.ini

Most of the time, it will correspond to:

	$HOME/.config/gedit/gedit-markdown.ini

The section `markdown-preview` contains several properties:

- `panel`: emplacement of the preview. Possibles values: `bottom` (default value) or `side`.

- `shortcut`: shortcut to refresh the preview. The default value is `<Control><Alt>m`.

- `extensions`: a whitespace separated list of [Markdown extensions](https://python-markdown.github.io/extensions/#officially-supported-extensions). See link for possible values. Defaults to "extra toc".

- `visibility`: visibility of the Markdown Preview panel tab when gedit starts. Possible values: `0` (hidden) or `1` (displayed; default value).

- `visibilityShortcut`: shortcut to toggle Markdown Preview visibility. The default value is `<Control><Alt>v`.

- `autoIdle`: only update markdown after this idle time (in milliseconds). Possible values: `0` (update immediately), `250` (default), any positive `float`.

- `autoReloadActivate`: automatically reload the preview when the plugin is activated. Possible values: `0` (disabled) or `1` (enabled; default value).

- `autoReloadOpen`: automatically reload the preview when the document is opened. Possible values: `0` (disabled) or `1` (enabled; default value).

- `autoReloadSave`: automatically reload the preview when the document is saved. Possible values: `0` (disabled) or `1` (enabled; default value).

- `autoReloadTabs`: automatically reload the preview when the active tab is changed. Possible values: `0` (disabled) or `1` (enabled; default value).

- `autoReloadEdit`: automatically reload the preview when the text is changed. Possible values: `0` (disabled) or `1` (enabled; default value).

- `autoReloadSelection`: automatically reload the preview when the selection is changed. Possible values: `0` (disabled; default value) or `1` (enabled).

Non-existent properties (as well as the whole file) will be generated with default values on startup.

### Examples

- [Demo 1](doc/demo-markdown.md)
- [Demo 2](doc/demo-markdown-extra.md)

## Details and limitations

- Syntax highlighting and snippets for standard Markdown were officially added in GtkSourceView and gedit > 3.1.1.

- Older versions of gedit-markdown also added Markdown MIME type and recognition of an additional extension (`.mdtxt`). Since Markdown support was added directly into the shared MIME database `shared-mime-info` ([see the bug report][bug27441]), gedit-markdown no longer adds its own Markdown MIME type file. Also, for purposes of compliance with the specification, the extension `.mdtxt` is no longer supported.

- Since HTML code can be directly used in a text written in Markdown, HTML syntax highlighting was added to Markdown syntax highlighting. However, keep in mind that, even if they're highlighted, Markdown syntax within HTML blocks (e.g. `<div>`) and Markdown Extra syntax within HTML blocks without `markdown` attribute set to 1 (e.g., `<div markdown="1">`) are not processed.

- Within a paragraph, text wrapped with backticks indicates a code span. Markdown allows to use one or more backticks to wrap text, provided that the number is identical on both sides, and the same number of consecutive backticks is not present within the text. Examples:

		`lorem lorem lorem lorem`
		
		`lorem lorem `` lorem lorem`
		
		`lorem lorem ````` lorem lorem`
		
		``lorem lorem lorem lorem``
		
		``lorem lorem ` lorem lorem``
		
		``lorem lorem ````` lorem lorem``

	Syntax highlighting in gedit supports code span highlighting with up to 2 backticks surrounding text.

- Blockquote can contain block-level and inline Markdown elements, but gedit-markdown only highlights inline ones (emphasis, link, etc.).

- A full context analysis can't be done (because line break can't be used in regex). Here are some consequences:

	- According to the Markdown syntax, to write several paragraphs in a list item, we have to indent each paragraph. Example:

			- Item A (paragraph 1).

				Item A (paragraph 2).

				Item A (paragraph 3).

			- Item B.

		So there is a conflict in terms of syntax highlighting between an indented paragraph inside a list item (4 spaces or 1 tab) and an indented line of code outside a list (also 4 spaces or 1 tab). The choice was made ​​​​to highlight code block only from 2 levels of indentation.

	- Only the underline of a Setext-style header is matched and highlighted, so there's no guarantee that it's indeed a title underline.

	- With Markdown Extra, some elements are matched and highlighted with no guarantee that they're in the right context: Setext-style header id attribute, colon used as separator in a definition list and separator line of a table.

[bug27441]: https://bugs.freedesktop.org/show_bug.cgi?id=27441

## Development

Git is used for revision control. [Repository can be browsed online or cloned.](https://github.com/jpfleury/gedit-markdown)

### Localization

The plugin *Markdown Preview* is localizable. The file containing strings is `plugins/markdown-preview/locale/markdown-preview.pot`.

## License

Maintener: Jean-Philippe Fleury  
Copyright © 2009-2014, 2025 Jean-Philippe Fleury <https://github.com/jpfleury>  
Copyright © 2018, 2020 darkdragon-001 <https://github.com/darkdragon-001>  
Copyright © 2005, 2006 Michele Campeotto <micampe@micampe.it>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
