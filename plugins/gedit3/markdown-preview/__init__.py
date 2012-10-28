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
import webbrowser

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

markdownExternalBrowser = "0"
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
parser.set("markdown-preview", "externalBrowser", markdownExternalBrowser)
parser.set("markdown-preview", "panel", markdownPanel)
parser.set("markdown-preview", "shortcut", markdownShortcut)
parser.set("markdown-preview", "version", markdownVersion)
parser.set("markdown-preview", "visibility", markdownVisibility)
parser.set("markdown-preview", "visibilityShortcut", markdownVisibilityShortcut)

if os.path.isfile(confFile):
	parser.read(confFile)
	markdownExternalBrowser = parser.get("markdown-preview", "externalBrowser")
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

class MarkdownPreviewPlugin(GObject.Object, Gedit.WindowActivatable):
	__gtype_name__ = "MarkdownPreviewPlugin"
	window = GObject.property(type=Gedit.Window)
	currentUri = ""
	overLinkUrl = ""
	
	def __init__(self):
		GObject.Object.__init__(self)
	
	def do_activate(self):
		self.scrolledWindow = Gtk.ScrolledWindow()
		self.scrolledWindow.set_property("hscrollbar-policy", Gtk.PolicyType.AUTOMATIC)
		self.scrolledWindow.set_property("vscrollbar-policy", Gtk.PolicyType.AUTOMATIC)
		self.scrolledWindow.set_property("shadow-type", Gtk.ShadowType.IN)
		
		self.htmlView = WebKit.WebView()
		self.htmlView.connect("hovering-over-link", self.onHoveringOverLinkCb)
		self.htmlView.connect("navigation-policy-decision-requested",
		                       self.onNavigationPolicyDecisionRequestedCb)
		self.htmlView.connect("populate-popup", self.onPopulatePopupCb)
		self.htmlView.load_string((htmlTemplate % ("", )), "text/html", "utf-8", "file:///")
		
		self.scrolledWindow.add(self.htmlView)
		self.scrolledWindow.show_all()
		
		if markdownVisibility == "1":
			self.addMarkdownPreviewTab()
		
		self.addMenuItems()
	
	def do_deactivate(self):
		# Remove menu items.
		manager = self.window.get_ui_manager()
		manager.remove_ui(self.uiId)
		manager.remove_action_group(self.actionGroup1)
		manager.remove_action_group(self.actionGroup2)
		
		# Remove Markdown Preview from the panel.
		self.removeMarkdownPreviewTab()
	
	def do_update_state(self):
		self.actionGroup1.set_sensitive(self.window.get_active_document() != None)
	
	def addMarkdownPreviewTab(self):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		image = Gtk.Image()
		image.set_from_icon_name("gnome-mime-text-html", Gtk.IconSize.MENU)
		
		panel.add_item(self.scrolledWindow, "MarkdownPreview", _("Markdown Preview"), image)
		panel.show()
		panel.activate_item(self.scrolledWindow)
	
	def addMenuItems(self):
		manager = self.window.get_ui_manager()
		
		self.actionGroup1 = Gtk.ActionGroup("UpdateMarkdownPreview")
		action = ("MarkdownPreview",
		          None,
		          _("Update Markdown Preview"),
		          markdownShortcut,
		          _("Preview in HTML of the current document or the selection"),
		          lambda x, y: self.updatePreview(y, False))
		self.actionGroup1.add_actions([action], self.window)
		manager.insert_action_group(self.actionGroup1, -1)
		
		self.actionGroup2 = Gtk.ActionGroup("ToggleTab")
		action = ("ToggleTab",
		          None,
		          _("Toggle Markdown Preview visibility"),
		          markdownVisibilityShortcut,
		          _("Display or hide the Markdown Preview panel tab"),
		          lambda x, y: self.toggleTab())
		self.actionGroup2.add_actions([action], self.window)
		manager.insert_action_group(self.actionGroup2, -1)
		
		self.uiId = manager.new_merge_id()
		
		manager.add_ui(self.uiId, "/MenuBar/ToolsMenu/ToolsOps_4",
		               "MarkdownPreview", "MarkdownPreview",
		               Gtk.UIManagerItemType.MENUITEM, True)
		
		manager.add_ui(self.uiId, "/MenuBar/ToolsMenu/ToolsOps_4",
		               "ToggleTab", "ToggleTab",
		               Gtk.UIManagerItemType.MENUITEM, False)
	
	def copyCurrentUrl(self):
		self.clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
		self.clipboard.set_text(self.currentUri, -1)
	
	def goToAnotherUrl(self):
		newUrl = self.goToAnotherUrlDialog()
		
		if newUrl:
			if newUrl.startswith("/"):
				newUrl = "file://" + newUrl
			
			self.htmlView.open(newUrl)
	
	def goToAnotherUrlDialog(self):
		dialog = Gtk.MessageDialog(None,
		                           Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
		                           Gtk.MessageType.QUESTION,
		                           Gtk.ButtonsType.OK_CANCEL,
		                           _("Enter URL"))
		dialog.set_title(_("Enter URL"))
		dialog.format_secondary_markup(_("Enter the URL (local or distant) of the document or page to display."))
		
		entry = Gtk.Entry()
		entry.connect("activate", self.onGoToAnotherUrlDialogActivateCb, dialog,
		              Gtk.ResponseType.OK)
		
		dialog.vbox.pack_end(entry, True, True, 0)
		dialog.show_all()
		
		response = dialog.run()
		
		newUrl = ""
		
		if response == Gtk.ResponseType.OK:
			newUrl = entry.get_text()
		
		dialog.destroy()
		
		return newUrl
	
	def onGoToAnotherUrlDialogActivateCb(self, entry, dialog, response):
		dialog.response(response)
	
	def onHoveringOverLinkCb(self, page, title, url):
		if url and not self.overLinkUrl:
			self.overLinkUrl = url
			
			self.urlTooltip = Gtk.Window.new(Gtk.WindowType.POPUP)
			self.urlTooltip.set_border_width(2)
			self.urlTooltip.modify_bg(0, Gdk.color_parse("#d9d9d9"))
			
			label = Gtk.Label()
			text = (url[:75] + "...") if len(url) > 75 else url
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
		else:
			self.overLinkUrl = ""
			
			if self.urlTooltipVisible():
				self.urlTooltip.destroy()
	
	def onNavigationPolicyDecisionRequestedCb(self, view, frame, networkRequest,
	                                          navAct, polDec):
		self.currentUri = networkRequest.get_uri()
		
		if self.currentUri == "file:///":
			activeDocument = self.window.get_active_document()
			
			if activeDocument:
				uriActiveDocument = activeDocument.get_uri_for_display()
				
				# Make sure we have an absolute path (so the file exists).
				if uriActiveDocument.startswith("/"):
					self.currentUri = uriActiveDocument
		
		if navAct.get_reason().value_nick == "link-clicked" and markdownExternalBrowser == "1":
			webbrowser.open_new_tab(self.currentUri)
			
			if self.urlTooltipVisible():
				self.urlTooltip.destroy()
			
			polDec.ignore()
		
		return False
	
	def openInEmbeddedBrowser(self):
		self.htmlView.open(self.overLinkUrl)
	
	def openInExternalBrowser(self):
		webbrowser.open_new_tab(self.overLinkUrl)
	
	def onPopulatePopupCb(self, view, menu):
		if self.urlTooltipVisible():
			self.urlTooltip.destroy()
		
		for item in menu.get_children():
			try:
				icon = item.get_image().get_stock()[0]
				
				if (icon == "gtk-copy" or icon == "gtk-go-back" or
				    icon == "gtk-go-forward" or icon == "gtk-stop"):
					continue
				elif icon == "gtk-refresh":
					if self.currentUri == "file:///":
						item.set_sensitive(False)
				else:
					menu.remove(item)
			except:
				menu.remove(item)
		
		if self.overLinkUrl:
			if markdownExternalBrowser == "1":
				item = Gtk.MenuItem(label=_("Open in the embedded browser"))
				item.connect("activate", lambda x: self.openInEmbeddedBrowser())
			else:
				item = Gtk.MenuItem(label=_("Open in an external browser"))
				item.connect("activate", lambda x: self.openInExternalBrowser())
			
			menu.append(item)
		
		item = Gtk.MenuItem(label=_("Copy the current URL"))
		item.connect("activate", lambda x: self.copyCurrentUrl())
		
		if self.currentUri == "file:///":
			item.set_sensitive(False)
		
		menu.append(item)
		
		item = Gtk.MenuItem(label=_("Go to another URL"))
		item.connect("activate", lambda x: self.goToAnotherUrl())
		menu.append(item)
		
		item = Gtk.MenuItem(label=_("Update Preview"))
		item.connect("activate", lambda x: self.updatePreview(self, False))
		
		documents = self.window.get_documents()
		
		if not documents:
			item.set_sensitive(False)
		
		menu.append(item)
		
		item = Gtk.MenuItem(label=_("Clear Preview"))
		item.connect("activate", lambda x: self.updatePreview(self, True))
		menu.append(item)
		
		menu.show_all()
	
	def removeMarkdownPreviewTab(self):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		panel.remove_item(self.scrolledWindow)
	
	def toggleTab(self):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		if panel.activate_item(self.scrolledWindow):
			self.removeMarkdownPreviewTab()
		else:
			self.addMarkdownPreviewTab()
	
	def updatePreview(self, window, clear):
		view = self.window.get_active_view()
		
		if not view and not clear:
			return
		
		html = ""
		
		if not clear:
			doc = view.get_buffer()
			start = doc.get_start_iter()
			end = doc.get_end_iter()
			
			if doc.get_selection_bounds():
				start = doc.get_iter_at_mark(doc.get_insert())
				end = doc.get_iter_at_mark(doc.get_selection_bound())
			
			text = doc.get_text(start, end, True).decode("utf-8")
			
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
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		
		panel.show()
		
		if not panel.activate_item(self.scrolledWindow):
			self.addMarkdownPreviewTab()
			panel.activate_item(self.scrolledWindow)
	
	def urlTooltipVisible(self):
		if hasattr(self, "urlTooltip") and self.urlTooltip.get_property("visible"):
			return True
		
		return False

