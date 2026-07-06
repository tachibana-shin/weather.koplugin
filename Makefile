WEATHER_ICONS_DIR := google-weather-icons
ICON_SRC := $(WEATHER_ICONS_DIR)/sets/set-4/light
ICON_DST := resources/google-weather/set-4

PLUGIN_DIR := weather.koplugin

.PHONY: all icons clean luacheck release

all: icons

icons: $(ICON_DST) $(WEATHER_ICONS_DIR)/.submodule_ready
	cp $(ICON_SRC)/*.svg $(ICON_DST)/

$(WEATHER_ICONS_DIR)/.submodule_ready:
	git submodule update --init $(WEATHER_ICONS_DIR)
	touch $@

$(ICON_DST):
	mkdir -p $(ICON_DST)

luacheck:
	luacheck .

release: luacheck icons
	rm -f $(PLUGIN_DIR).zip
	mkdir -p $(PLUGIN_DIR)
	cp *.lua $(PLUGIN_DIR)/
	rm -f $(PLUGIN_DIR)/weather_settings.lua
	cp -r providers weathercards resources $(PLUGIN_DIR)/
	cd $(PLUGIN_DIR) && zip -r ../$(PLUGIN_DIR).zip .
	rm -rf $(PLUGIN_DIR)
	@echo "Created $(PLUGIN_DIR).zip"

clean:
	rm -rf $(ICON_DST) $(PLUGIN_DIR).zip $(WEATHER_ICONS_DIR)/.submodule_ready
