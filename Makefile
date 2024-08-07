C4_SRCS_DIR := ./c4model
C4_DIST_DIR := ./images

C4_SRCS := $(shell find $(C4_SRCS_DIR) -name '*.puml')
C4_PNGS=$(C4_SRCS:$(C4_SRCS_DIR)/%.puml=$(C4_DIST_DIR)/%.png)

all: README.md $(C4_PNGS)

.PHONY: view

README.md: README-unprocessed.md
	pandoc 	--lua-filter=pandoc-include-code.lua \
		--from=gfm+attributes \
		--to=gfm \
		--output $@ \
		$? 

$(C4_DIST_DIR)/%.png: $(C4_SRCS_DIR)/%.puml
	mkdir -p $(C4_DIST_DIR)
	cat $< | plantuml -tpng -pipe > $@

view: $(C4_PNGS)
	firefox $(C4_PNGS)
