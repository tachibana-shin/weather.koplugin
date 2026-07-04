WEATHER_ICONS_REPO := https://github.com/mrdarrengriffin/google-weather-icons.git
WEATHER_ICONS_DIR := google-weather-icons
ICON_SRC := $(WEATHER_ICONS_DIR)/sets/set-4/light
ICON_DST := resources/google-weather/set-4

.PHONY: all icons clean

all: icons

icons: $(ICON_DST)
	cp $(ICON_SRC)/*.svg $(ICON_DST)/

$(WEATHER_ICONS_DIR):
	git clone $(WEATHER_ICONS_REPO) $(WEATHER_ICONS_DIR)

$(ICON_DST):
	mkdir -p $(ICON_DST)

clean:
	rm -rf $(ICON_DST)
