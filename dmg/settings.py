# dmgbuild settings. build.sh passes the paths:
#   dmgbuild -s dmg/settings.py -D app=... -D background=... "AirPod Clicker" out.dmg
import os

app = defines["app"]  # noqa: F821 (injected by dmgbuild)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}

background = defines["background"]  # noqa: F821
window_rect = ((200, 200), (600, 380))
icon_size = 112
text_size = 13
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
icon_locations = {
    os.path.basename(app): (160, 175),
    "Applications": (440, 175),
}
