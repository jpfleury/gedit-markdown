#!/usr/bin/python
# -*- coding: utf-8 -*-

# Le fichier markdownpreview.py fait partie de markdownpreview.
# HTML preview of Markdown formatted text in gedit
# Auteur: Michele Campeotto
# Copyright © Michele Campeotto, 2005, 2006.
# Copyright © Jean-Philippe Fleury, 2009, 2011. <contact@jpfleury.net>

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

import os
import gedit
import sys
import gtk
import webkit
import markdown
import gettext
from ConfigParser import SafeConfigParser
from gpdefs import *

try:
	APP_NAME = 'markdown-preview'
	LOCALE_PATH = os.path.dirname(__file__) + '/locale'
	gettext.bindtextdomain(APP_NAME, LOCALE_PATH)
	_ = lambda s: gettext.dgettext(APP_NAME, s);
except:
	_ = lambda s: s

# Can be used to add default HTML code (e.g. default header section with CSS).
HTML_TEMPLATE = "%s"

# Configuration.
CONFIG_PATH = os.path.dirname(__file__) + '/config.ini'
parser = SafeConfigParser()
parser.read(CONFIG_PATH)
markdownVersion = parser.get('markdown', 'version')

# Tab title.

tabTitle = _("Markdown Preview")

if markdownVersion == "extra":
	tabTitle = _("Markdown Extra Preview")

class MarkdownPreviewPlugin(gedit.Plugin):
	def __init__(self):
		gedit.Plugin.__init__(self)
	
	def activate(self, window):
		action = ("Markdown Preview", None, tabTitle, "<Control><Alt>M",
		          _("Update the HTML preview"), lambda x, y: self.update_preview(y))
		
		# Store data in the window object.
		windowdata = dict()
		window.set_data("MarkdownPreviewData", windowdata)
	
		scrolled_window = gtk.ScrolledWindow()
		scrolled_window.set_property("hscrollbar-policy", gtk.POLICY_AUTOMATIC)
		scrolled_window.set_property("vscrollbar-policy", gtk.POLICY_AUTOMATIC)
		scrolled_window.set_property("shadow-type", gtk.SHADOW_IN)
		
		html_view = webkit.WebView()
		html_view.load_string((HTML_TEMPLATE % ("", )), "text/html", "utf-8", "file:///")
		
		scrolled_window.add(html_view)
		scrolled_window.show_all()
		
		bottom_panel = window.get_bottom_panel()
		image = gtk.Image()
		image.set_from_icon_name("gnome-mime-text-html", gtk.ICON_SIZE_MENU)
		bottom_panel.add_item(scrolled_window, tabTitle, image)
		bottom_panel.show()
		
		windowdata["bottom_panel"] = scrolled_window
		windowdata["html_doc"] = html_view
		windowdata["action_group"] = gtk.ActionGroup("MarkdownPreviewActions")
		windowdata["action_group"].add_actions([action], window)

		manager = window.get_ui_manager()
		manager.insert_action_group(windowdata["action_group"], -1)

		windowdata["ui_id"] = manager.new_merge_id()

		manager.add_ui(windowdata["ui_id"], "/MenuBar/ToolsMenu/ToolsOps_5",
		               "Markdown Preview", "Markdown Preview", gtk.UI_MANAGER_MENUITEM, True)
	
	def deactivate(self, window):
		# Retreive data of the window object.
		windowdata = window.get_data("MarkdownPreviewData")
		
		# Remove the menu action.
		manager = window.get_ui_manager()
		manager.remove_ui(windowdata["ui_id"])
		manager.remove_action_group(windowdata["action_group"])
		
		# Remove Markdown Preview from the bottom panel.
		bottom_panel = window.get_bottom_panel()
		bottom_panel.remove_item(windowdata["bottom_panel"])
	
	def update_preview(self, window):
		# Retreive data of the window object.
		windowdata = window.get_data("MarkdownPreviewData")
		
		view = window.get_active_view()
		
		if not view:
			return
		
		doc = view.get_buffer()
		start = doc.get_start_iter()
		end = doc.get_end_iter()
		
		if doc.get_selection_bounds():
			start = doc.get_iter_at_mark(doc.get_insert())
			end = doc.get_iter_at_mark(doc.get_selection_bound())
		
		text = doc.get_text(start, end)
		
		if markdownVersion == "extra":
			html = HTML_TEMPLATE % (markdown.markdown(text, extensions=['fenced_code', 'footnotes', 'headerid', 'def_list', 'tables', 'abbr',]), )
		else:
			html = HTML_TEMPLATE % (markdown.markdown(text), )
		
		p = windowdata["bottom_panel"].get_placement()
		html_doc = windowdata["html_doc"]
		html_doc.load_string(html, "text/html", "utf-8", "file:///")
		windowdata["bottom_panel"].set_placement(p)
		
		bottom_panel = window.get_bottom_panel()
		bottom_panel.show()
		bottom_panel.activate_item(windowdata["bottom_panel"])

