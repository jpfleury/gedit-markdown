#!/usr/bin/python
# -*- coding: utf-8 -*-

# HTML preview of Markdown formatted text in gedit
# Copyright © 2005, 2006 Michele Campeotto
# Copyright © 2009, 2011 Jean-Philippe Fleury <contact@jpfleury.net>

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
markdownPanel = parser.get('markdown', 'panel')
markdownShortcut = parser.get('markdown', 'shortcut')
markdownVersion = parser.get('markdown', 'version')

class MarkdownPreviewPlugin(gedit.Plugin):
	def __init__(self):
		gedit.Plugin.__init__(self)
	
	def activate(self, window):
		action = ("Markdown Preview", None, _("Markdown Preview"), markdownShortcut,
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
		
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		image = gtk.Image()
		image.set_from_icon_name("gnome-mime-text-html", gtk.ICON_SIZE_MENU)
		panel.add_item(scrolled_window, _("Markdown Preview"), image)
		panel.show()
		
		windowdata["panel"] = scrolled_window
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
		
		# Remove Markdown Preview from the panel.
		
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		panel.remove_item(windowdata["panel"])
	
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
			html = HTML_TEMPLATE % (markdown.markdown(text, extensions=['extra']), )
		else:
			html = HTML_TEMPLATE % (markdown.markdown(text, smart_emphasis=False), )
		
		p = windowdata["panel"].get_placement()
		html_doc = windowdata["html_doc"]
		html_doc.load_string(html, "text/html", "utf-8", "file:///")
		windowdata["panel"].set_placement(p)
		
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		panel.show()
		panel.activate_item(windowdata["panel"])

