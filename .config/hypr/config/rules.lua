-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ WINDOW & LAYER RULES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

hl.layer_rule({ match = { namespace = "^(volume_osd)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^(brightness_osd)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "hyprpicker" }, no_anim = true })
hl.layer_rule({ match = { namespace = "qsdock" }, no_anim = true })
hl.layer_rule({ match = { namespace = "ext-session-lock" }, blur = true, ignore_alpha = 0.2 })

-- Quickshell layer blur rules
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^(qs-master)$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^(qs-popups)$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^(qs-floating-overlay)$" }, blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ match = { namespace = "^(qs-screenshot-overlay)$" }, blur = true, ignore_alpha = 0.2 })

-- Window rules
hl.window_rule({
	match = { title = "^(app-launcher)$" },
	float = true,
	center = true,
	size = { 1200, 600 },
	animation = "slide",
})
hl.window_rule({ match = { title = "^(qs-master)$" }, float = true, no_shadow = true, no_initial_focus = true })
hl.window_rule({ match = { workspace = "special:spotify_discord" }, opacity = 0.75 })
hl.window_rule({ match = { class = "^(discord)$" }, workspace = "special:spotify_discord silent" })
hl.window_rule({ match = { class = "(?i)^(spotify)$" }, workspace = "special:spotify_discord silent" })
hl.window_rule({ match = { title = "(?i)^(spotify.*)$" }, workspace = "special:spotify_discord silent" })
