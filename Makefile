# Configuration
AI_NAME = AdmiralAI
AI_VERSION = 26
DIRS = rail road air utils network
FILES = COPYING *.nut
# End of configuration

NAME_VERSION = $(AI_NAME)-$(AI_VERSION)
TAR_NAME = $(NAME_VERSION).tar


all: info.nut

info.nut:
	@sed -i 's/revision = .*;/revision = '`hg id -n | cut -d+ -f1`';/' version.nut
	@sed -i 's/version_major = .*;/version_major = $(AI_VERSION);/' info.nut

bundle_tar: Makefile $(FILES)
	@mkdir "$(NAME_VERSION)"
	@for d in $(DIRS); do mkdir $(NAME_VERSION)/$$d; cp $$d/*.nut $(NAME_VERSION)/$$d; done
	@cp $(FILES) "$(NAME_VERSION)"
	@tar -cf "$(TAR_NAME)" "$(NAME_VERSION)"
	@rm -r "$(NAME_VERSION)"

.PHONY: info.nut
