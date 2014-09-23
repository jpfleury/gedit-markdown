#!/usr/bin/python
# -*- coding: utf-8 -*-

# HTML preview of Markdown formatted text in gedit
# Copyright © 2005, 2006 Michele Campeotto
# Copyright © 2009 Jean-Philippe Fleury <contact@jpfleury.net>

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

try:
	appName = "markdown-preview"
	fileDir = os.path.dirname(__file__)
	localePath = os.path.join(fileDir, "locale")
	gettext.bindtextdomain(appName, localePath)
	_ = lambda s: gettext.dgettext(appName, s);
except:
	_ = lambda s: s

# Can be used to add default HTML code (e.g. default header section with CSS).
htmlTemplate = "%s"

# Configuration.

markdownPanel = "bottom"
markdownShortcut = "<Control><Alt>m"
markdownVersion = "extra"
markdownVisibility = "1"
markdownVisibilityShortcut = "<Control><Alt>v"

try:
	import xdg.BaseDirectory
except ImportError:
	homeDir = os.environ.get("HOME")
	xdgConfigHome = os.path.join(homeDir, ".config")
else:
	xdgConfigHome = xdg.BaseDirectory.xdg_config_home

confDir =  os.path.join(xdgConfigHome, "gedit")
confFile =  os.path.join(confDir, "gedit-markdown.ini")

parser = SafeConfigParser()
parser.optionxform = str
parser.add_section("markdown-preview")
parser.set("markdown-preview", "panel", markdownPanel)
parser.set("markdown-preview", "shortcut", markdownShortcut)
parser.set("markdown-preview", "version", markdownVersion)
parser.set("markdown-preview", "visibility", markdownVisibility)
parser.set("markdown-preview", "visibilityShortcut", markdownVisibilityShortcut)

if os.path.isfile(confFile):
	parser.read(confFile)
	markdownPanel = parser.get("markdown-preview", "panel")
	markdownShortcut = parser.get("markdown-preview", "shortcut")
	markdownVersion = parser.get("markdown-preview", "version")
	markdownVisibility = parser.get("markdown-preview", "visibility")
	markdownVisibilityShortcut = parser.get("markdown-preview", "visibilityShortcut")
	# Delete an option mistakenly added in previous versions.
	parser.remove_option("markdown-preview", "pythonSitePackages")

if not os.path.exists(confDir):
	os.makedirs(confDir)

with open(confFile, "wb") as confFile:
	parser.write(confFile)

class MarkdownPreviewPlugin(gedit.Plugin):
	def __init__(self):
		gedit.Plugin.__init__(self)
	
	def activate(self, window):
		self.scrolledWindow = gtk.ScrolledWindow()
		self.scrolledWindow.set_property("hscrollbar-policy", gtk.POLICY_AUTOMATIC)
		self.scrolledWindow.set_property("vscrollbar-policy", gtk.POLICY_AUTOMATIC)
		self.scrolledWindow.set_property("shadow-type", gtk.SHADOW_IN)
		
		self.htmlView = webkit.WebView()
		self.htmlView.props.settings.props.enable_default_context_menu = False
		self.htmlView.load_string((htmlTemplate % ("", )), "text/html", "utf-8", "file:///")
		
		self.scrolledWindow.add(self.htmlView)
		self.scrolledWindow.show_all()
		
		if markdownVisibility == "1":
			self.addMarkdownPreviewTab(window)
		
		self.addMenuItems(window)
	
	def deactivate(self, window):
		# Remove the menu item.
		manager = window.get_ui_manager()
		manager.remove_ui(self.uiId)
		manager.remove_action_group(self.actionGroup1)
		
		# Remove Markdown Preview from the panel.
		self.removeMarkdownPreviewTab(window)
	
	def addMarkdownPreviewTab(self, window):
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		image = gtk.Image()
		image.set_from_icon_name("gnome-mime-text-html", gtk.ICON_SIZE_MENU)
		
		panel.add_item(self.scrolledWindow, _("Markdown Preview"), image)
		panel.show()
		panel.activate_item(self.scrolledWindow)
	
	def addMenuItems(self, window):
		manager = window.get_ui_manager()
		
		self.actionGroup1 = gtk.ActionGroup("UpdateMarkdownPreview")
		action = ("MarkdownPreview",
		          None,
		          _("Update Markdown Preview"),
		          markdownShortcut,
		          _("Preview in HTML of the current document or the selection"),
		          lambda x, y: self.updatePreview(y))
		self.actionGroup1.add_actions([action], window)
		manager.insert_action_group(self.actionGroup1, -1)
		
		self.actionGroup2 = gtk.ActionGroup("ToggleTab")
		action = ("ToggleTab",
		          None,
		          _("Toggle Markdown Preview visibility"),
		          markdownVisibilityShortcut,
		          _("Display or hide the Markdown Preview panel tab"),
		          lambda x, y: self.toggleTab(y))
		self.actionGroup2.add_actions([action], window)
		manager.insert_action_group(self.actionGroup2, -1)
		
		self.uiId = manager.new_merge_id()
		
		manager.add_ui(self.uiId, "/MenuBar/ToolsMenu/ToolsOps_4",
		               "MarkdownPreview", "MarkdownPreview",
		               gtk.UI_MANAGER_MENUITEM, True)
		
		manager.add_ui(self.uiId, "/MenuBar/ToolsMenu/ToolsOps_4",
		               "ToggleTab", "ToggleTab",
		               gtk.UI_MANAGER_MENUITEM, False)
	
	def removeMarkdownPreviewTab(self, window):
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		panel.remove_item(self.scrolledWindow)
	
	def toggleTab(self, window):
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		if panel.activate_item(self.scrolledWindow):
			self.removeMarkdownPreviewTab(window)
		else:
			self.addMarkdownPreviewTab(window)
	
	def updatePreview(self, window):
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
		
		if markdownVersion == "standard":
			html = htmlTemplate % (markdown.markdown(text, smart_emphasis=False), )
		else:
			html = htmlTemplate % (markdown.markdown(text, extensions=["extra",
			                       "headerid(forceid=False)"]), )
		
		placement = self.scrolledWindow.get_placement()
		
		htmlDoc = self.htmlView
		htmlDoc.load_string(html, "text/html", "utf-8", "file:///")
		
		self.scrolledWindow.set_placement(placement)
		
		if markdownPanel == "side":
			panel = window.get_side_panel()
		else:
			panel = window.get_bottom_panel()
		
		if not panel.activate_item(self.scrolledWindow):
			self.addMarkdownPreviewTab(window)
		
		panel.show()
		panel.activate_item(self.scrolledWindow)

