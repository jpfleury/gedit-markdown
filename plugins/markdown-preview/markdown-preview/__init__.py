#!/usr/bin/python3
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

import gi
gi.require_version('WebKit2', '4.0')
from gi.repository import Gdk, Gtk, GtkSource, Gedit, GObject, WebKit2, Gio
import os
import sys
import markdown
import gettext
from configparser import ConfigParser
import timeit
from threading import Timer
import webbrowser

try:
	appName = "markdown-preview"
	fileDir = os.path.dirname(__file__)
	localePath = os.path.join(fileDir, "locale")
	gettext.bindtextdomain(appName, localePath)
	gettext.textdomain(appName)
	_ = gettext.gettext
except:
	_ = lambda s: s

# Configuration.

markdownPanel = "bottom"
markdownShortcut = "<Control><Alt>m"
markdownExtensions = "extra toc"
markdownVisibility = "0"  # TODO BUG crash on startup when markdownAutoReloadTabs="0"
markdownVisibilityShortcut = "<Control><Alt>v"
markdownAutoIdle = "250"
markdownAutoReloadActivate = "1"
markdownAutoReloadOpen = "1"
markdownAutoReloadSave = "1"
markdownAutoReloadTabs = "0"  # TODO BUG https://gitlab.gnome.org/GNOME/gedit/-/issues/322
markdownAutoReloadEdit = "1"
markdownAutoReloadSelection = "0"

try:
	import xdg.BaseDirectory
except ImportError:
	homeDir = os.environ.get("HOME")
	xdgConfigHome = os.path.join(homeDir, ".config")
else:
	xdgConfigHome = xdg.BaseDirectory.xdg_config_home

confDir =  os.path.join(xdgConfigHome, "gedit/markdown-preview")
confFile =  os.path.join(confDir, "preferences.ini")

parser = ConfigParser()
parser.optionxform = str
parser.add_section("markdown-preview")
parser.set("markdown-preview", "panel", markdownPanel)
parser.set("markdown-preview", "shortcut", markdownShortcut)
parser.set("markdown-preview", "extensions", markdownExtensions)
parser.set("markdown-preview", "visibility", markdownVisibility)
parser.set("markdown-preview", "visibilityShortcut", markdownVisibilityShortcut)
parser.set("markdown-preview", "autoIdle", markdownAutoIdle)
parser.set("markdown-preview", "autoReloadActivate", markdownAutoReloadActivate)
parser.set("markdown-preview", "autoReloadOpen", markdownAutoReloadOpen)
parser.set("markdown-preview", "autoReloadSave", markdownAutoReloadSave)
parser.set("markdown-preview", "autoReloadTabs", markdownAutoReloadTabs)
parser.set("markdown-preview", "autoReloadEdit", markdownAutoReloadEdit)
parser.set("markdown-preview", "autoReloadSelection", markdownAutoReloadSelection)

if os.path.isfile(confFile):
	parser.read(confFile)
	markdownPanel = parser.get("markdown-preview", "panel")
	markdownShortcut = parser.get("markdown-preview", "shortcut")
	markdownExtensions = parser.get("markdown-preview", "extensions")
	markdownVisibility = parser.get("markdown-preview", "visibility")
	markdownVisibilityShortcut = parser.get("markdown-preview", "visibilityShortcut")
	markdownAutoIdle = parser.get("markdown-preview", "autoIdle")
	markdownAutoReloadActivate = parser.get("markdown-preview", "autoReloadActivate")
	markdownAutoReloadOpen = parser.get("markdown-preview", "autoReloadOpen")
	markdownAutoReloadSave = parser.get("markdown-preview", "autoReloadSave")
	markdownAutoReloadTabs = parser.get("markdown-preview", "autoReloadTabs")
	markdownAutoReloadEdit = parser.get("markdown-preview", "autoReloadEdit")
	markdownAutoReloadSelection = parser.get("markdown-preview", "autoReloadSelection")

if not os.path.exists(confDir):
	os.makedirs(confDir)

with open(confFile, "w") as confFile:
	parser.write(confFile)

markdownExtensionsList = markdownExtensions.split()
markdownAutoIdleSeconds = float(markdownAutoIdle) / 1000.

# HTML template (e.g. default CSS).
htmlTemplate = ""
templateFile = os.path.join(confDir, "template.html")
with open(templateFile, 'r') as f:
	htmlTemplate = f.read()

# Path converter for absolute paths if available
try:
	from pymdownx.pathconverter import PathConverterExtension
	pathConverterAvailable = True
except:
	pathConverterAvailable = False

class MarkdownPreviewPlugin(GObject.Object, Gedit.WindowActivatable):
	__gtype_name__ = "MarkdownPreviewPlugin"
	window = GObject.property(type=Gedit.Window)

	def __init__(self):
		GObject.Object.__init__(self)

	def do_activate(self):
		self.scrolledWindow = Gtk.ScrolledWindow()  # TODO replace by something simpler (scroll is handled by WebKit2.WebView)
		self.scrolledWindow.set_property("hscrollbar-policy", Gtk.PolicyType.AUTOMATIC)
		self.scrolledWindow.set_property("vscrollbar-policy", Gtk.PolicyType.AUTOMATIC)
		self.scrolledWindow.set_property("shadow-type", Gtk.ShadowType.IN)

		self.htmlView = WebKit2.WebView()
		self.htmlView.get_settings().set_property('enable_javascript', True)
		self.htmlView.connect('load-changed', self.onLoadChanged)
		self.htmlView.connect("mouse-target-changed", self.onMouseTargetChangedCb)
		self.htmlView.connect("decide-policy", self.onDecidePolicyCb)
		self.htmlView.connect("context-menu", self.onContextMenuCb)
		if markdownAutoReloadActivate == "1":
			self.updatePreview(reason='pluginActivated')

		self.scrolledWindow.add(self.htmlView)
		self.scrolledWindow.show_all()

		if markdownVisibility == "1":
			self.addMarkdownPreviewTab()

		self.addWindowActions()

		self.handleTabChanged = self.window.connect("active-tab-changed", self.onTabChangedCb)
		self.handleTabStateChanged = self.window.connect("active-tab-state-changed", self.onTabChangedCb)
		self.addBufferSignals()

	# This is called every time the document is changed
	def do_update_state(self, *args):
		if markdownAutoReloadEdit == "1":
			self.autoUpdate(self.window)

	def do_deactivate(self):
		# Remove signals
		self.removeBufferSignals()
		self.window.disconnect(self.handleTabChanged)
		self.window.disconnect(self.handleTabStateChanged)
		# Remove actions
		self.window.remove_action('MarkdownPreview')
		self.window.remove_action('ToggleTab')
		self.action_update = None
		self.action_toggle = None
		# Remove Markdown Preview from the panel.
		self.removeMarkdownPreviewTab()
		# delete instance variables
		self.scrolledWindow = None
		self.htmlView = None


	# Windows and Signals

	def getMarkdownPanel(self):
		if markdownPanel == "side":
			panel = self.window.get_side_panel()
		else:
			panel = self.window.get_bottom_panel()
		return panel

	def isMarkdownPreviewTabAdded(self):
		panel = self.getMarkdownPanel()
		return panel.get_child_by_name("MarkdownPreview") is not None
	def isMarkdownPreviewTabVisible(self):
		panel = self.getMarkdownPanel()
		return panel.get_visible_child_name() == "MarkdownPreview"
	def isMarkdownPreviewVisible(self):
		return self.scrolledWindow.get_mapped()  # self and all parents visible

	def addMarkdownPreviewTab(self):
		panel = self.getMarkdownPanel()
		if not panel.is_visible():
			panel.show()
		if not self.isMarkdownPreviewTabAdded():
			panel.add_titled(self.scrolledWindow, "MarkdownPreview", _("Markdown Preview"))
		if not self.isMarkdownPreviewTabVisible():
			panel.set_visible_child_name("MarkdownPreview")
		self.updatePreview(reason='previewVisible')

	def removeMarkdownPreviewTab(self):
		panel = self.getMarkdownPanel()
		if self.isMarkdownPreviewTabAdded():
			panel.remove(self.scrolledWindow)
		panel.hide()

	def toggleTab(self):
		if not self.isMarkdownPreviewVisible():
			self.addMarkdownPreviewTab()
		else:
			self.removeMarkdownPreviewTab()

	def addWindowActions(self):
		self.action_update = Gio.SimpleAction(name='MarkdownPreview')
		self.action_update.connect('activate', lambda x, y: self.updatePreview(reason='userAction'))
		self.window.add_action(self.action_update)

		self.action_toggle = Gio.SimpleAction(name='ToggleTab')
		self.action_toggle.connect('activate', lambda x, y: self.toggleTab())
		self.window.add_action(self.action_toggle)

	def addBufferSignals(self):
		self.removeBufferSignals()

		view = self.window.get_active_view()
		if view:
			self.handleBuffer = view.get_buffer()
			self.handleMarkSet = self.handleBuffer.connect("mark-set", self.onMarkSetCb)
			self.handleDocumentLoaded = self.handleBuffer.connect("loaded", self.onDocumentLoadedCb)
			self.handleDocumentSaved = self.handleBuffer.connect("saved", self.onDocumentSavedCb)

	def removeBufferSignals(self):
		if (hasattr(self, "handleMarkSet") and self.handleMarkSet is not None and
			hasattr(self, "handleBuffer") and self.handleBuffer is not None):
			self.handleBuffer.disconnect(self.handleMarkSet)
			self.handleBuffer.disconnect(self.handleDocumentLoaded)
			self.handleBuffer.disconnect(self.handleDocumentSaved)
			del self.handleBuffer
			del self.handleMarkSet
			del self.handleDocumentLoaded
			del self.handleDocumentSaved

	def rememberScroll(self, *args):
		js = 'window.document.body.scrollTop'
		self.htmlView.run_javascript(js, None, self.onRememberScrollFinished, None)

	def restoreScroll(self, *args):
		if hasattr(self, "scrollRestore") and self.scrollRestore:  # only restore on reload, not on navigation
			if hasattr(self, "scrollPosition") and self.scrollPosition:
				js = 'window.document.body.scrollTop = ' + str(self.scrollPosition)
				self.htmlView.run_javascript(js, None, None, None)
			self.scrollRestore = False

	def onRememberScrollFinished(self, webview, result, user_data):
		js_result = webview.run_javascript_finish(result)
		if js_result is not None:
			value = js_result.get_js_value()
			if not value.is_undefined():
				self.scrollPosition = value.to_int32()


	# Callbacks

	def onTabChangedCb(self, *args):
		self.addBufferSignals()

		if markdownAutoReloadTabs == "1":
			self.updatePreview(reason='tabChanged')

	def onMarkSetCb(self, buf, loc, mark):
		if markdownAutoReloadSelection == "1":
			if mark.get_name() == "insert":
				doc = self.handleBuffer
				start = doc.get_iter_at_mark(doc.get_selection_bound())
				end = doc.get_iter_at_mark(mark)
				if not start.equal(end):
					# selection changed
					self.autoUpdate()
					self.activeSelection = True
				else:
					if hasattr(self, "activeSelection") and self.activeSelection:
						# selection removed
						self.autoUpdate()
						self.activeSelection = False

	def onDocumentLoadedCb(self, *args):
		if markdownAutoReloadOpen == "1":
			self.updatePreview(reason='documentLoaded')

	def onDocumentSavedCb(self, *args):
		if markdownAutoReloadSave == "1":
			self.updatePreview(reason='documentSaved')

	def onLoadChanged(self, view, loadEvent):
		self.restoreScroll()

	def onMouseTargetChangedCb(self, view, hitTestResult, modifiers):
		self.rememberScroll()  # TODO find better event for scrolling with keyboard, scrollbar, etc.

		if hitTestResult.context_is_link():
			url = hitTestResult.get_link_uri()
			text = (url[:75] + "...") if len(url) > 75 else url
			self.window.set_tooltip_text(text)
		else:
			self.window.set_has_tooltip(False)

	def onDecidePolicyCb(self, view, decision, decisionType):
		if decisionType == WebKit2.PolicyDecisionType.NAVIGATION_ACTION: # type(decision) == WebKit2.NavigationPolicyDecision
			# Navigate to new uri
			currentUri = decision.get_request().get_uri()
			if currentUri.startswith("file:///"):
				# allow navigating local files
				if currentUri.startswith(self.getActiveUri()):
					# re-render current document to allow "back" functionality and avoid confusion on unsaved files
					self.updatePreview(reason='navigation')
					decision.ignore()
				else:
					# render other local files
					lang = GtkSource.LanguageManager.get_default().guess_language(currentUri, None)
					if lang is None:
						self.render()
					if lang.get_id() == "html":
						decision.use()
					elif lang.get_id() == "markdown":
						with open(currentUri[7:], 'r') as file:  # remove "file://"
							text = file.read()
							self.render(text, currentUri, True)
					else:
						self.render()
			else:
				# open in new browser tab
				webbrowser.open_new_tab(currentUri)
				decision.ignore()
		elif decisionType == WebKit2.PolicyDecisionType.NEW_WINDOW_ACTION:  # type(decision) == WebKit2.NavigationPolicyDecision
			# Forbid new windows
			decision.ignore()
		elif decisionType == WebKit2.PolicyDecisionType.RESPONSE:  # type(decision) == WebKit2.ResponsePolicyDecision
			# Allow all responses
			decision.use()
		else:  # WebKit2.PolicyDecision
			# Forbid everything else
			decision.ignore()

		return True

	def onContextMenuCb(self, view, menu, event, hitTestResult):
		for item in menu.get_items():
			try:
				stockAction = item.get_stock_action()
				if (stockAction == WebKit2.ContextMenuAction.OPEN_LINK or
					stockAction == WebKit2.ContextMenuAction.COPY_LINK_TO_CLIPBOARD or
					stockAction == WebKit2.ContextMenuAction.GO_BACK or
					stockAction == WebKit2.ContextMenuAction.GO_FORWARD):
					continue
				else:
					menu.remove(item)
			except:
				menu.remove(item)

		if not hitTestResult.context_is_link():
			item = WebKit2.ContextMenuItem.new_from_gaction(self.action_update, _("Update Preview"))
			menu.append(item)


	# Rendering

	lastUpdate = 0.
	def autoUpdate(self, *args):
		if markdownAutoIdleSeconds > 0:
			self.lastUpdate = timeit.default_timer()
			Timer(markdownAutoIdleSeconds, self.autoUpdateTimerCb, args=[self,*args]).start()
		else:
			self.updatePreview(self, *args, reason='editor')
	def autoUpdateTimerCb(self, *args):
		markdownAutoIdleSeconds = float(markdownAutoIdle) / 1000.
		if ( timeit.default_timer() - self.lastUpdate ) >= markdownAutoIdleSeconds:
			self.updatePreview(self, *args, reason='editor')

	def updatePreview(self, *args, **kwargs):
		view = self.window.get_active_view()
		if not view:
			return
		doc = view.get_buffer()
		lang = doc.get_language()
		if lang and lang.get_id() in ["markdown", "html"]:
			start = doc.get_start_iter()
			end = doc.get_end_iter()

			if markdownAutoReloadSelection == "1" and doc.get_selection_bounds():
				start = doc.get_iter_at_mark(doc.get_selection_bound())
				end = doc.get_iter_at_mark(doc.get_insert())

			text = doc.get_text(start, end, True)

			if lang.get_id() == "html":
				isMarkdown = False
			elif lang.get_id() == "markdown":
				isMarkdown = True

			activeUri = self.getActiveUri()

			self.render(text, activeUri, isMarkdown)

			if 'reason' in kwargs and kwargs['reason'] != 'navigation':
				self.scrollRestore = True  # NOTE this is not called after onDecidePolicyCb when navigating
		else:
			self.render()  # empty page

	def render(self, html=None, activeUri=None, isMarkdown=False):
		if not self.isMarkdownPreviewVisible():
			return

		if html is None:
			html = ""
		if activeUri is None:
			activeUri = "file:///"

		basePathWebView = self.uriToBase(activeUri)
		if isMarkdown:
			extensions = markdownExtensionsList
			# Use PathConverter extension if available
			# This avoids the WebView restriction of only accessing files *below* base_path
			# https://lazka.github.io/pgi-docs/#WebKit2-4.0/classes/WebView.html#WebKit2.WebView.load_html
			if pathConverterAvailable:
				basePathWebView = "file:///"
				# BUG: base_path can't be prefixed with "file://"
				#      https://github.com/facelessuser/pymdown-extensions/issues/921
				basePathConverter = self.uriToBase(activeUri)[7:]  # remove "file://" because of bug above
				extensions.append(PathConverterExtension(base_path=basePathConverter, absolute=True))
			html = htmlTemplate % markdown.markdown(html, extensions=extensions)
		self.htmlView.load_alternate_html(html, activeUri, basePathWebView)

	def getActiveUri(self):
		activeUri = self.window.get_active_document().get_uri_for_display()  # Absolute paths when existing file
		if len(activeUri)<1 or activeUri[0] != '/':  # File does not exist
			activeUri = '/' + activeUri  # force valid local URI
		return "file://" + activeUri


	def uriToBase(self, uri):
		# cases: "file:///", "file:///path/to/file", "file:///Untitled Document 1"
		return uri.rpartition("/")[0]+"/"


class MarkdownPreviewMenu(GObject.Object, Gedit.AppActivatable):
	app = GObject.property(type=Gedit.App)

	def __init__(self):
		GObject.Object.__init__(self)

	def do_activate(self):
		self.app.set_accels_for_action("win.MarkdownPreview", [markdownShortcut])
		self.app.set_accels_for_action("win.ToggleTab", [markdownVisibilityShortcut])

		self.tools_menu_ext = self.extend_menu("tools-section")

		md_prev_update = Gio.MenuItem.new(_("Update Markdown Preview"), "win.MarkdownPreview")
		md_prev_toggle = Gio.MenuItem.new(_("Toggle Markdown Preview Visibility"), "win.ToggleTab")

		self.tools_menu_ext.append_menu_item(md_prev_update)
		self.tools_menu_ext.append_menu_item(md_prev_toggle)

	def do_deactivate(self):
		self.app.set_accels_for_action("win.MarkdownPreview", [])
		self.app.set_accels_for_action("win.ToggleTab", [])

		self.tools_menu_ext = None
