# Configuration
AI_NAME = AdmiralAI
AI_VERSION = 14
FILES = COPYING *.nut
# End of configuration

NAME_VERSION = $(AI_NAME).$(AI_VERSION)
TAR_NAME = $(NAME_VERSION).tar


all: bundle

bundle: Makefile $(FILES)
	@mkdir "$(NAME_VERSION)"
	@cp $(FILES) "$(NAME_VERSION)"
	@tar -cf "$(TAR_NAME)" "$(NAME_VERSION)"
	@rm -r "$(NAME_VERSION)"

	