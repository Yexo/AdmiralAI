# Configuration
AI_NAME = AdmiralAI
AI_VERSION = 24
DIRS = rail road air utils network
FILES = COPYING *.nut
# End of configuration

NAME_VERSION = $(AI_NAME)-$(AI_VERSION)
TAR_NAME = $(NAME_VERSION).tar


all: bundle

bundle: Makefile $(FILES)
	@mkdir "$(NAME_VERSION)"
	@for d in $(DIRS); do mkdir $(NAME_VERSION)/$$d; cp $$d/*.nut $(NAME_VERSION)/$$d; done
	@cp $(FILES) "$(NAME_VERSION)"
	@tar -cf "$(TAR_NAME)" "$(NAME_VERSION)"
	@rm -r "$(NAME_VERSION)"
