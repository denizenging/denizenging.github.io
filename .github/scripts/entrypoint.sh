#!/bin/sh

apk --no-cache add make poppler-utils typst pandoc-cli
make setup md pdf