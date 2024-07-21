TYP = $(shell find page post -type f -name \*.typ)
MD = $(TYP:.typ=.md)
PDF = $(TYP:.typ=.pdf)
EPUB = $(MD:.md=.epub)

NOW=$(shell TZ=UTC date '+%Y-%m-%dT%H:%M:%S')

.PHONY: dev setup clean md epub pdf 

dev: md epub pdf
	hugo --config func/hugo.yml serve
md: ${MD}
epub: ${EPUB}
pdf: ${PDF}
clean:
	@rm -f ${MD} ${PDF} ${EPUB}

setup: 
	for p in util page post; do \
		mkdir -p ~/.local/share/typst/packages/local/pub-"$$p"; \
		test -e ~/.local/share/typst/packages/local/pub-"$$p"/0.0.0 \
			|| ln -s "$$(realpath ".typst/$$p")" \
				~/.local/share/typst/packages/local/pub-"$$p"/0.0.0; \
	done

%.md: %.typ
	@echo "Building $@ from $<"
	typst c -f pdf --input building=md --input now="${NOW}" \
		 --input path="$<" "$<" /dev/stdout \
	| pdftotext - - \
	| sed 's,␊,\n,g; s,␉,\t,g; s,␠, ,g; s,␞,\n\n,g; s,,,g' >"$@"

%.epub: %.md
	@echo "Building $@ from $<"
	pandoc -o "$@" "$<" 

%.pdf: %.typ
	@echo "Building $@ from $<"
	typst c -f pdf --input building=pdf --input now="${NOW}" \
		--input path="$<" "$<"