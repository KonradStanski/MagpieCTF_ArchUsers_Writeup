MD_SOURCES := $(wildcard **/*.md)
PDF_TARGETS := $(MD_SOURCES:%.md=%.pdf)

all: $(PDF_TARGETS)

%.pdf: %.md
	pandoc metadata.yaml $< \
		--from markdown \
		--pdf-engine=xelatex \
		--highlight-style haddock \
		-V papersize:letter \
		-o $@

.PHONY: clean

clean:
	-rm -f $(PDF_TARGETS)
