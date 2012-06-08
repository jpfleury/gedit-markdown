#!/usr/bin/python
# -*- coding: utf-8 -*-

# HTML preview of Markdown formatted text in gedit
# Copyright © 2005, 2006 Michele Campeotto
# Copyright © 2009, 2011-2012 Jean-Philippe Fleury <contact@jpfleury.net>

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

from gi.repository import Gdk, Gtk, Gedit, GObject, WebKit
import codecs
import os
import sys
import markdown
import gettext
from ConfigParser import SafeConfigParser

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

try:
	import xdg.BaseDirectory
except ImportError:
	home = os.environ.get('HOME')
	xdg_config_home = os.path.join(home, '.config/')
else:
	xdg_config_home = xdg.BaseDirectory.xdg_config_home

confDir =  os.path.join(xdg_config_home, 'gedit/')
confFile =  os.path.join(confDir, 'gedit-markdown.ini')
parser = SafeConfigParser()

if os.path.isfile(confFile):
	parser.read(confFile)
	markdownPanel = parser.get('markdown-preview', 'panel')
	markdownShortcut = parser.get('markdown-preview', 'shortcut')
	markdownVersion = parser.get('markdown-preview', 'version')
else:
	markdownPanel = 'bottom'
	markdownShortcut = '<Control><Alt>m'
	markdownVersion = 'extra'
	
	if not os.path.exists(confDir):
		os.makedirs(confDir)
	
	parser.add_section('markdown-preview')
	parser.set('markdown-preview', 'panel', markdownPanel)
	parser.set('markdown-preview', 'shortcut', markdownShortcut)
	parser.set('markdown-preview', 'version', markdownVersion)
	with open(confFile, 'wb') as confFile:
		parser.write(confFile)

class MarkdownPreviewPlugin(GObject.Object, Gedit.WindowActivatable):
	__gtype_name__ = "MarkdownPreviewPlugin"
	window = GObject.property(type=Gedit.Window)
	
	def __init__(self):
		GObject.Object.__init__(self)
	
	def do_activate(self):
		# Store data in the window object.
		windowdata = dict()
		self.window.set_data("MarkdownPreviewData", windowdata)
		
		scrolled_window = Gtk.ScrolledWindow()
		scrolled_window.set_property("hscrollbar-policy", Gtk.PolicyType.AUTOMATIC)
		scrolled_window.set_property("vscrollbar-policy", Gtk.PolicyType.AUTOMATIC)
		scrolled_window.set_property("shadow-type", Gtk.ShadowType.IN)
		
		html_view = WebKit.WebView()
		html_view.connect("hovering-over-link", self.hovering_over_link)
		html_view.connect("navigation-requested", self.navigation_requested)
		html_view.connect("populate-popup", self.populate_popup)
		html_view.load_string((HTML_TEMPLATE % ("", )), "text/html", "utf-8", "file:///")
		
		scrolled_window.add(html_view)
		scrolled_window.show_all()
		
		windowdata["panel"] = scrolled_window
		windowdata["html_doc"] = html_view
		
		self.add_markdown_preview_tab(windowdata)
		self.add_menu_items(windowdata)
	
	def do_deactivate(self):
		# Retreive data of the window object.
		windowdata = self.window.get_data("MarkdownPreviewData")
		
		# Remove menu items.
		manager = self.window.get_ui_manager()
		manager.remove_ui(windowdata["ui_id"])
		manager.remove_action_group(windowdata["action_group"])
		
		# Remove Markdown Preview from the panel.
		self.remove_markdown_preview_tab(windowdata)
	
	def add_markdown_preview_tab(self, windowdata):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		image = Gtk.Image()
		image.set_from_icon_name("gnome-mime-text-html", Gtk.IconSize.MENU)
		panel.add_item(windowdata["panel"], "MarkdownPreview", _("Markdown Preview"), image)
		panel.show()
		panel.activate_item(windowdata["panel"])
	
	def add_menu_items(self, windowdata):
		windowdata["action_group"] = Gtk.ActionGroup("MarkdownPreviewActions")
		
		action = ("MarkdownPreview",
		          None,
		          _("Update Markdown Preview"),
		          markdownShortcut,
		          _("Preview in HTML of the current document or the selection"),
		          lambda x, y: self.update_preview(y, False))
		windowdata["action_group"].add_actions([action], self.window)
		
		action = ("ToggleTab",
		          None,
		          _("Toggle Markdown Preview visibility"),
		          None,
		          _("Display or hide the Markdown Preview panel tab"),
		          lambda x, y: self.toggle_tab(windowdata))
		windowdata["action_group"].add_actions([action], self.window)
		
		manager = self.window.get_ui_manager()
		manager.insert_action_group(windowdata["action_group"], -1)
		
		windowdata["ui_id"] = manager.new_merge_id()
		
		manager.add_ui(windowdata["ui_id"], "/MenuBar/ToolsMenu/ToolsOps_4",
		               "ToggleTab", "ToggleTab", Gtk.UIManagerItemType.MENUITEM, True)
		manager.add_ui(windowdata["ui_id"], "/MenuBar/ToolsMenu/ToolsOps_4",
		               "MarkdownPreview", "MarkdownPreview", Gtk.UIManagerItemType.MENUITEM, True)
	
	def hovering_over_link(self, page, title, url):
		if url:
			self.urlTooltip = Gtk.Window.new(Gtk.WindowType.POPUP)
			self.urlTooltip.set_border_width(2)
			self.urlTooltip.modify_bg(0, Gdk.color_parse("white"))
			label = Gtk.Label()
			text = (url[:75] + '...') if len(url) > 75 else url
			label.set_text(text)
			label.modify_fg(0, Gdk.color_parse("black"))
			self.urlTooltip.add(label)
			label.show()
			self.urlTooltip.show()
			
			xPointer, yPointer = self.urlTooltip.get_pointer()
			xWindow = self.window.get_position()[0]
			widthWindow = self.window.get_size()[0]
			widthUrlTooltip = self.urlTooltip.get_size()[0]
			
			xUrlTooltip = xPointer
			yUrlTooltip = yPointer + 15
			xOverflow = (xUrlTooltip + widthUrlTooltip) - (xWindow + widthWindow)
			
			if xOverflow > 0:
				xUrlTooltip = xUrlTooltip - xOverflow
			
			self.urlTooltip.move(xUrlTooltip, yUrlTooltip)
		elif self.urlTooltip:
			self.urlTooltip.destroy()
	
	def navigation_requested(self, view, frame, networkRequest):
		self.window.currentUri = networkRequest.get_uri()
		return False
	
	def populate_popup(self, view, menu):
		if self.urlTooltip:
			self.urlTooltip.destroy()
		
		for item in menu.get_children():
			try:
				icon = item.get_image().get_stock()[0]
				
				if (icon == "gtk-copy" or icon == "gtk-go-back" or
				    icon == "gtk-go-forward" or icon == "gtk-stop"):
					continue
				elif icon == "gtk-refresh":
					if self.window.currentUri == "file:///":
						item.set_sensitive(False)
				else:
					menu.remove(item)
			except:
				menu.remove(item)
		
		item = Gtk.MenuItem(label=_("Update Preview"))
		item.connect('activate', lambda x: self.update_preview(self, False))
		menu.append(item)
		item = Gtk.MenuItem(label=_("Clear Preview"))
		item.connect('activate', lambda x: self.update_preview(self, True))
		menu.append(item)
		menu.show_all()
	
	def remove_markdown_preview_tab(self, windowdata):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		panel.remove_item(windowdata["panel"])
	
	def toggle_tab(self, windowdata):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		if panel.activate_item(windowdata["panel"]):
			self.remove_markdown_preview_tab(windowdata)
		else:
			self.add_markdown_preview_tab(windowdata)
	
	def update_preview(self, window, clear):
		# Retreive data of the window object.
		windowdata = self.window.get_data("MarkdownPreviewData")
		
		view = self.window.get_active_view()
		
		if not view:
			return
		
		doc = view.get_buffer()
		start = doc.get_start_iter()
		end = doc.get_end_iter()
		
		if doc.get_selection_bounds():
			start = doc.get_iter_at_mark(doc.get_insert())
			end = doc.get_iter_at_mark(doc.get_selection_bound())
		
		html = ""
		
		if not clear:
			text = doc.get_text(start, end, True).decode('utf-8')
			
			if markdownVersion == "standard":
				html = HTML_TEMPLATE % (markdown.markdown(text, smart_emphasis=False), )
			else:
				html = HTML_TEMPLATE % (markdown.markdown(text, extensions=['extra', 'headerid(forceid=False)']), )
		
		p = windowdata["panel"].get_placement()
		html_doc = windowdata["html_doc"]
		html_doc.load_string(html, "text/html", "utf-8", "file:///")
		windowdata["panel"].set_placement(p)
		
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		panel.show()
		
		if not panel.activate_item(windowdata["panel"]):
			self.add_markdown_preview_tab(windowdata)
			panel.activate_item(windowdata["panel"])

