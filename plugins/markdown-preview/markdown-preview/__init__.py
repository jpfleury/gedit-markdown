#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
This file is part of gedit-markdown.
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
"""

from __future__ import annotations

import gettext
import os
import timeit
import urllib.parse
import webbrowser
from configparser import ConfigParser
from threading import Timer

import gi

for wkVersion in ["4.1", "4.0"]:
    try:
        gi.require_version("WebKit2", wkVersion)
        break
    except ValueError:
        continue
else:
    raise ImportError("No compatible version of WebKit2 found")

from gi.repository import (
    Gedit,
    Gio,
    GObject,
    Gtk,
    GtkSource,
    Tepl,
    WebKit2,
)

try:
    import markdown
except ImportError as exc:
    raise ImportError(
        "The python-markdown package is required for markdown-preview."
    ) from exc

try:
    from pymdownx.pathconverter import PathConverterExtension

    _PATHCONVERTER = True
except ImportError:
    _PATHCONVERTER = False

APP_NAME = "markdown-preview"
LOCALE_DIR = os.path.join(os.path.dirname(__file__), "locale")
gettext.bindtextdomain(APP_NAME, LOCALE_DIR)
gettext.textdomain(APP_NAME)
_ = gettext.gettext


def _xdg_config_home() -> str:
    try:
        import xdg.BaseDirectory as _xdg

        return _xdg.xdg_config_home
    except Exception:
        return os.path.join(os.environ.get("HOME", "~"), ".config")


CONF_DIR = os.path.join(_xdg_config_home(), "gedit", APP_NAME)
CONF_FILE = os.path.join(CONF_DIR, "preferences.ini")
TEMPLATE_FILE = os.path.join(CONF_DIR, "template.html")

_DEFAULTS: dict[str, str] = {
    "panel": "bottom",
    "shortcut": "<Control><Alt>m",
    "extensions": "extra toc",
    "visibility": "0",
    "visibilityShortcut": "<Control><Alt>v",
    "autoIdle": "250",
    "autoReloadActivate": "1",
    "autoReloadOpen": "1",
    "autoReloadSave": "1",
    "autoReloadTabs": "0",
    "autoReloadEdit": "1",
    "autoReloadSelection": "0",
}

cfg = ConfigParser()
cfg.optionxform = str  # Keep key case
cfg.add_section(APP_NAME)
for k, v in _DEFAULTS.items():
    cfg.set(APP_NAME, k, v)
if os.path.isfile(CONF_FILE):
    cfg.read(CONF_FILE)
os.makedirs(CONF_DIR, exist_ok=True)
with open(CONF_FILE, "w", encoding="utf-8") as _fp:
    cfg.write(_fp)

P = lambda k: cfg.get(APP_NAME, k)

markdownPanel = P("panel")
markdownShortcut = P("shortcut")
markdownExtensions = P("extensions")
markdownVisibility = P("visibility")
markdownVisibilityShortcut = P("visibilityShortcut")
markdownAutoIdle = P("autoIdle")
markdownAutoReloadActivate = P("autoReloadActivate")
markdownAutoReloadOpen = P("autoReloadOpen")
markdownAutoReloadSave = P("autoReloadSave")
markdownAutoReloadTabs = P("autoReloadTabs")
markdownAutoReloadEdit = P("autoReloadEdit")
markdownAutoReloadSelection = P("autoReloadSelection")

markdownExtensionsList = markdownExtensions.split()
markdownAutoIdleSeconds = float(markdownAutoIdle) / 1000.0

try:
    with open(TEMPLATE_FILE, "r", encoding="utf-8") as _fp:
        htmlTemplate = _fp.read()
except FileNotFoundError:
    htmlTemplate = """<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>%s</body></html>"""


class MarkdownPreviewPlugin(GObject.Object, Gedit.WindowActivatable):
    __gtype_name__ = "MarkdownPreviewPlugin"

    window: Gedit.Window = GObject.Property(type=Gedit.Window)

    lastUpdate: float = 0.0
    scrollRestore: bool = False
    scrollPosition: int | None = None
    activeSelection: bool = False

    def do_activate(self):
        self.panel_item = None
        self.scrolledWindow = Gtk.ScrolledWindow()
        self.scrolledWindow.set_policy(
            Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC
        )
        self.scrolledWindow.set_property("shadow-type", Gtk.ShadowType.IN)

        self.htmlView = WebKit2.WebView()
        self.htmlView.get_settings().set_property("enable_javascript", True)
        self.htmlView.connect("load-changed", self.onLoadChanged)
        self.htmlView.connect("mouse-target-changed", self.onMouseTargetChangedCb)
        self.htmlView.connect("decide-policy", self.onDecidePolicyCb)
        self.htmlView.connect("context-menu", self.onContextMenuCb)

        self.scrolledWindow.add(self.htmlView)
        self.scrolledWindow.show_all()

        if markdownVisibility == "1":
            self.addMarkdownPreviewTab()

        self.addWindowActions()
        self.handleTabChanged = self.window.connect(
            "active-tab-changed", self.onTabChangedCb
        )
        self.handleTabStateChanged = self.window.connect(
            "active-tab-state-changed", self.onTabChangedCb
        )
        self.addBufferSignals()

        if markdownAutoReloadActivate == "1":
            self.updatePreview(reason="pluginActivated")

    def do_deactivate(self):
        self.removeBufferSignals()
        self.window.disconnect(self.handleTabChanged)
        self.window.disconnect(self.handleTabStateChanged)
        self.window.remove_action("MarkdownPreview")
        self.window.remove_action("ToggleTab")
        self.removeMarkdownPreviewTab()
        if self.htmlView is not None:
            self.htmlView.destroy()
        if self.scrolledWindow is not None:
            self.scrolledWindow.destroy()
        self.htmlView = None
        self.scrolledWindow = None

    def getMarkdownPanel(self):
        return (
            self.window.get_side_panel()
            if markdownPanel == "side"
            else self.window.get_bottom_panel()
        )

    def isMarkdownPreviewTabAdded(self):
        return self.scrolledWindow.get_parent() is not None

    def isMarkdownPreviewTabVisible(self):
        panel = self.getMarkdownPanel()
        if hasattr(panel, "get_visible_child"):
            return panel.get_visible_child() == self.scrolledWindow
        if hasattr(panel, "get_visible_child_name"):
            return panel.get_visible_child_name() == "MarkdownPreview"
        return False

    def isMarkdownPreviewVisible(self):
        """Return True if the preview widget is currently mapped (visible)."""
        return self.scrolledWindow.get_mapped()

    def addMarkdownPreviewTab(self):
        panel = self.getMarkdownPanel()
        panel.set_visible(True)
        try:
            self.panel_item = Tepl.Panel.add(
                panel,
                self.scrolledWindow,
                "MarkdownPreview",
                _("Markdown Preview"),
                None,
            )
        except Exception as e:
            print("Erreur Tepl.Panel.add :", e)
            self.panel_item = None
            return
        self.updatePreview(reason="previewVisible")

    def removeMarkdownPreviewTab(self):
        panel = self.getMarkdownPanel()
        if self.panel_item:
            try:
                Tepl.Panel.remove(panel, self.panel_item)
                panel.set_visible(False)
            except Exception as e:
                print("Error Tepl.Panel.remove:", e)

    def toggleTab(self):
        """Toggle visibility of the preview tab."""
        if not self.isMarkdownPreviewVisible():
            self.addMarkdownPreviewTab()
        else:
            self.removeMarkdownPreviewTab()

    def addWindowActions(self):
        self.action_update = Gio.SimpleAction(name="MarkdownPreview")
        self.action_update.connect(
            "activate", lambda *_: self.updatePreview(reason="userAction")
        )
        self.window.add_action(self.action_update)
        self.action_toggle = Gio.SimpleAction(name="ToggleTab")
        self.action_toggle.connect("activate", lambda *_: self.toggleTab())
        self.window.add_action(self.action_toggle)

    def addBufferSignals(self):
        self.removeBufferSignals()
        view = self.window.get_active_view()
        if view:
            self.handleBuffer = view.get_buffer()
            self.handleMarkSet = self.handleBuffer.connect("mark-set", self.onMarkSetCb)
            self.handleDocumentLoaded = self.handleBuffer.connect(
                "loaded", self.onDocumentLoadedCb
            )
            self.handleDocumentSaved = self.handleBuffer.connect(
                "saved", self.onDocumentSavedCb
            )

    def removeBufferSignals(self):
        if hasattr(self, "handleBuffer") and self.handleBuffer is not None:
            self.handleBuffer.disconnect(self.handleMarkSet)
            self.handleBuffer.disconnect(self.handleDocumentLoaded)
            self.handleBuffer.disconnect(self.handleDocumentSaved)
            del (
                self.handleBuffer,
                self.handleMarkSet,
                self.handleDocumentLoaded,
                self.handleDocumentSaved,
            )

    def rememberScroll(self, *_):
        js = "window.document.body.scrollTop"
        self.htmlView.run_javascript(js, None, self.onRememberScrollFinished, None)

    def restoreScroll(self, *_):
        if self.scrollRestore and self.scrollPosition is not None:
            js = f"window.document.body.scrollTop = {self.scrollPosition}"
            self.htmlView.run_javascript(js, None, None, None)
            self.scrollRestore = False

    def onRememberScrollFinished(self, webview, result, _):
        res = webview.run_javascript_finish(result)
        if res is not None:
            value = res.get_js_value()
            if not value.is_undefined():
                self.scrollPosition = value.to_int32()

    def onTabChangedCb(self, *_):
        self.addBufferSignals()
        if markdownAutoReloadTabs == "1":
            self.updatePreview(reason="tabChanged")

    def onMarkSetCb(self, _buf, _loc, mark):
        if markdownAutoReloadSelection == "1" and mark.get_name() == "insert":
            doc = self.handleBuffer
            start = doc.get_iter_at_mark(doc.get_selection_bound())
            end = doc.get_iter_at_mark(mark)
            if not start.equal(end):
                self.autoUpdate()
                self.activeSelection = True
            elif self.activeSelection:
                self.autoUpdate()
                self.activeSelection = False

    def onDocumentLoadedCb(self, *_):
        if markdownAutoReloadOpen == "1":
            self.updatePreview(reason="documentLoaded")

    def onDocumentSavedCb(self, *_):
        if markdownAutoReloadSave == "1":
            self.updatePreview(reason="documentSaved")

    def onLoadChanged(self, *_):
        self.restoreScroll()

    def onMouseTargetChangedCb(self, _view, hitTestResult, _):
        self.rememberScroll()
        if hitTestResult.context_is_link():
            url = hitTestResult.get_link_uri()
            text = (url[:75] + "…") if len(url) > 75 else url
            self.window.set_tooltip_text(text)
        else:
            self.window.set_has_tooltip(False)

    def onDecidePolicyCb(self, _view, decision, decisionType):
        if decisionType == WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            currentUri = decision.get_request().get_uri()
            if currentUri.startswith("file:///"):
                if currentUri.startswith(self.getActiveUri()):
                    self.updatePreview(reason="navigation")
                    decision.ignore()
                else:
                    lang = GtkSource.LanguageManager.get_default().guess_language(
                        currentUri, None
                    )
                    if lang and lang.get_id() == "html":
                        decision.use()
                    elif lang and lang.get_id() == "markdown":
                        with open(currentUri[7:], "r", encoding="utf-8") as _fp:
                            text = _fp.read()
                            self.render(text, currentUri, True)
                        decision.ignore()
                    else:
                        self.render()
                        decision.ignore()
            else:
                webbrowser.open_new_tab(currentUri)
                decision.ignore()
        elif decisionType == WebKit2.PolicyDecisionType.NEW_WINDOW_ACTION:
            decision.ignore()
        elif decisionType == WebKit2.PolicyDecisionType.RESPONSE:
            decision.use()
        else:
            decision.ignore()
        return True

    def onContextMenuCb(self, _view, menu, _event, hitTestResult):
        for item in menu.get_items():
            try:
                act = item.get_stock_action()
                if act in (
                    WebKit2.ContextMenuAction.OPEN_LINK,
                    WebKit2.ContextMenuAction.COPY_LINK_TO_CLIPBOARD,
                    WebKit2.ContextMenuAction.GO_BACK,
                    WebKit2.ContextMenuAction.GO_FORWARD,
                ):
                    continue
                menu.remove(item)
            except Exception:
                menu.remove(item)
        if not hitTestResult.context_is_link():
            menu.append(
                WebKit2.ContextMenuItem.new_from_gaction(
                    self.action_update, _("Update Preview")
                )
            )

    def autoUpdate(self, *_):
        if markdownAutoIdleSeconds > 0:
            self.lastUpdate = timeit.default_timer()
            Timer(markdownAutoIdleSeconds, self.autoUpdateTimerCb).start()
        else:
            self.updatePreview(reason="editor")

    def autoUpdateTimerCb(self):
        if (timeit.default_timer() - self.lastUpdate) >= markdownAutoIdleSeconds:
            self.updatePreview(reason="editor")

    def updatePreview(self, *_, **kwargs):
        view = self.window.get_active_view()
        if not view:
            return
        doc = view.get_buffer()
        lang = doc.get_language()
        if lang and lang.get_id() in ("markdown", "html"):
            start = doc.get_start_iter()
            end = doc.get_end_iter()
            if markdownAutoReloadSelection == "1" and doc.get_selection_bounds():
                start = doc.get_iter_at_mark(doc.get_selection_bound())
                end = doc.get_iter_at_mark(doc.get_insert())
            text = doc.get_text(start, end, True)
            isMarkdown = lang.get_id() == "markdown"
            self.render(text, self.getActiveUri(), isMarkdown)
            if kwargs.get("reason") != "navigation":
                self.scrollRestore = True
        else:
            self.render()

    def render(
        self, html: str = "", activeUri: str | None = None, isMarkdown: bool = False
    ):
        if not self.isMarkdownPreviewVisible():
            return
        activeUri = activeUri or "file:///"
        basePathWebView = self.uriToBase(activeUri)
        if isMarkdown:
            ext = list(markdownExtensionsList)
            if _PATHCONVERTER:
                basePathWebView = "file:///"
                baseConv = self.uriToBase(activeUri)[7:]
                ext.append(PathConverterExtension(base_path=baseConv, absolute=True))
            html = htmlTemplate % markdown.markdown(html, extensions=ext)
        self.htmlView.load_alternate_html(html, activeUri, basePathWebView)

    def getActiveUri(self) -> str:
        doc = self.window.get_active_document()
        if doc is None:
            return "file:///"
        if hasattr(doc, "get_file"):
            tfile = doc.get_file()
            if tfile is not None:
                loc = tfile.get_location()
                if loc is not None:
                    return loc.get_uri()
        if hasattr(doc, "get_location"):
            loc = doc.get_location()
            if loc is not None:
                return loc.get_uri()
        if hasattr(doc, "get_uri_for_display"):
            uri = doc.get_uri_for_display()
            if uri:
                return uri if uri.startswith("file://") else "file://" + uri
        title = doc.get_short_title() if hasattr(doc, "get_short_title") else "untitled"
        return f"file:///{urllib.parse.quote(title)}"

    @staticmethod
    def uriToBase(uri: str) -> str:
        return uri.rpartition("/")[0] + "/"


class MarkdownPreviewMenu(GObject.Object, Gedit.AppActivatable):
    """Adds 'Update Markdown Preview' and 'Toggle Markdown Preview Visibility' to the Tools menu."""

    app: Gedit.App = GObject.Property(type=Gedit.App)

    def do_activate(self):
        # Shortcuts
        self.app.set_accels_for_action("win.MarkdownPreview", [markdownShortcut])
        self.app.set_accels_for_action("win.ToggleTab", [markdownVisibilityShortcut])

        # Menu items
        self.tools_menu_ext = self.extend_menu("tools-section")
        self.tools_menu_ext.append_menu_item(
            Gio.MenuItem.new(_("Update Markdown Preview"), "win.MarkdownPreview")
        )
        self.tools_menu_ext.append_menu_item(
            Gio.MenuItem.new(_("Toggle Markdown Preview Visibility"), "win.ToggleTab")
        )

    def do_deactivate(self):
        # Remove shortcuts
        self.app.set_accels_for_action("win.MarkdownPreview", [])
        self.app.set_accels_for_action("win.ToggleTab", [])
        self.tools_menu_ext = None
