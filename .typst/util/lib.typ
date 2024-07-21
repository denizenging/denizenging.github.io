#let _building = sys.inputs.at("building", default: none)
#let abbr(title, body) = if _building == "md" {
	"<abbr title=" + json.encode(title)
	">" + body + "</abbr>"
} else [
	#body#footnote(title)
]

#let _lang(lang, region: none) = if _building == "md" {
	lang = lang + if region != none { "-" + region }
	(body) => {
		"<span lang=" + json.encode(lang) + ">"
		body
		"</span>"
	}
} else {
	(body) => text(lang: lang, region: region, body)
}

#let en = _lang("eng")
#let uk = _lang("eng", region: "uk")
#let us = _lang("eng", region: "us")
#let tr = _lang("tur", region: "tr")
#let fr = _lang("fra")
#let es = _lang("spa")
#let de = _lang("deu")
#let ja = _lang("jpn")
#let zh = _lang("zho")

// Hey, that's me!
#let author = "Engin, Deniz"

/// Given a string of the form `year-month-dayThour:minute:second`,
/// create a `datetime` using the providde values in the string.
#let parse-datetime(str) = {
	let (date, time) = sys.inputs.at("now").split("T")
	let (year, mon, day) = date.split("-")
	let (hour, min, sec) = time.split(":")
	datetime(
		year: int(year),
		month: int(mon),
		day: int(day),
		hour: int(hour),
		minute: int(min),
		second: int(sec),
	)
}

/// Given filename of the format `*.$lang.typ`, where `$lang` is
/// a two-letter language code, parse it fetch the `$lang` part.
#let parse-lang(filename) = {
	let lang = filename.split(".").at(-2)
	if lang not in ("en", "tr", "de", "jp", "eo", "es") {
		panic("invalid language: " + lang)
	}
	lang
}

/// Convent a two-letter language code to 2-element tuple of 3-letter
/// language code, and a region identifier (of my choice). 
#let lang-to-lang-region(lang) = {
	if lang == "en" {
		("eng", "us")
	} else if lang == "tr" {
		("tur", "tr")
	} else {
		// TODO: learn more L2 languages
		panic("invalid lang: " + lang)
	}
}

/// The main entrypoint for outputting markdown. This template procedure
/// is used to output markdown-like syntax with a little bit of extra
/// characters (to protect whitespace), which is later cleared by `sed`.
#let typst-to-markdown(frontmatter: none) = (body) => {
	set page(width: auto, height: auto)
	set text(ligatures: false)

	// needs some love:
	// - nested quote(block: true)
	// - links without body
	// - links with titles
	// - tables
	// - definition list (term lists?)

	// These characters are used to represent "pictures" of the
	// characters themselves, except for Record Separator (see Unicode
	// list). I shall note: were there any picture equivalent of
	// Paragraph Separator, it woulb to be used instead.
	// According to the Unicode standard, however, the Record Separator
	// is allowed to delimit paragraphs.
	let tab = "␉"
	let blank = "␠"
	let newline = "␊"
	let parbrk = "␞"

	show strong: it => [\*\*#it.body\*\*]
	show emph: it => [\*#it.body\*]
	show strike: it => [\~\~#it.body\~\~]
	show highlight: it => [==#it.body==]

	show image: it => { "![" + it.alt + "](" + it.path + ")" }

	// If `link`s start with a local path, we use it to refer to the
	// files of our own, which get translated to appropriate language.
	show link: it => if it.dest.starts-with("/") {
		[[#it.body](\{\{\< ref #json.encode(it.dest) >}})]
	} else {
		[[#it.body](#it.dest)]
	}

	// Since our theme doesn't like us using first-level headings, we
	// opt out and increase each heading's level by one, which is more
	// ergonomical since we can start off by using `=` instead of `==`
	//  each time we'd like to create a heading.
	show heading: it => {
		"#" * (it.level + 1)
		" "
		it.body
		linebreak()
	}

	// Quotes handle single-line quotes as well as multi-line quotes
	// where there exists newlines (`parbreak`s) in between.
	// TODO: nested quotes
	show quote.where(block: true): it => {
		let last = it.body.children.len() - 1
		"> "
		for i in range(last + 1) {
			let c = it.body.children.at(i)
			if c.func() == parbreak and i != last {
				newline + "> " + newline + "> "
			} else {
				c
			}
		}
	}

	// Raw texts is challinging, since when printing, it looses what's
	// the essential usage of it: keeping spaces. The spacing is lost,
	// the characters we're trying to read, that is, when printing. So,
	// we convert them to special characters we then use `sed` to
	// convert back to proper spacing.
	show raw: it => {
		let text = it.text
		.replace(" ", blank)
		.replace("\t", tab)
		.replace("\n", newline)
		if it.block {
			"```" + it.lang + newline + text + newline + "```"
		} else if it.lang != none {
			"```" + it.lang + " " + text + "```"
		} else {
			"`" + text + "`"
		}
	}

	// Now, lists require special care here. Since nested lists
	//  necessitate to be marked with proper indentation. The following
	// code handles that.
	//
	// See `list` and `enum` below for the reason of `type` and` mark`
	// parameters. On a sidenode, we are allowed to use only `1.` in
	//  ordered in place of ordinary, increasing numbers, which is
	// exploided here to not keep track of the numbers as well.
	let recurse(type, mark, item, level) = {
		if item.func() == type {
			if level != 0 {
				newline
			}
			tab * level
			mark
			" "
			if item.body.has("children") {
				for c in item.body.children {
					recurse(type, mark, c, level + 1)
				}
			} else {
				recurse(type, mark, item.body, level)
			}
		} else if item.has("text") {
			item.text
		} else if item == [ ] {
			" "
		} else if item.has("body") {
			item
		}
	}

	show list: it => for c in it.children {
		recurse(list.item, "-", c, 0)
		linebreak()
	}
	show enum: it => for c in it.children {
		recurse(enum.item, "1.", c, 0)
		linebreak()
	}

	// Footnotes are really easy. We just convert the mark of the
	// referent footnote to be of `[^1]` (which is supported by
	// markdown), and that of the refence footnote to `[^1]: `(which is,
	// again, supported by markdown).
	set footnote(numbering: "[^1]")
	show footnote.entry: it => {
		let loc = it.note.location()
		numbering(
			"[^1]: ",
			..counter(footnote).at(loc),
		)
		it.note.body
	}

	// And, the front matter. This is the easy part, because we can
	// leverage the rich data exchange untitities of typst here. I used
	// to use json here, but later switched to yaml, as it is accepted
	// by pandoc as well, which is later used to convert markdown files
	// we "transpiled" from typst to epub.
	//
	// The decision of choosing json first wasn't arbitrary. As one can
	// clearly see, using yaml requires more elobarate solutions here.
	if frontmatter != none {
		// "---"
		// newline
		// The author part is for pandoc, and solely used for that.
		// yaml.encode(frontmatter + (author: (author,)))
		// .replace(" ", blank)
		// .replace("\n", newline)
		// .replace("\t", tab)
		// newline
		// "---"
		json.encode(pretty: false, frontmatter)
	}

	show parbreak: parbrk
	body
}

/// The template used for previewing, that is when not building or
/// publishing PDFs or MDs. This is where one might want to change
/// color and font size for viewing.
#let typst-to-preview(title, date) = (body) => {
	set document(
		title: title,
		author: author,
		date: date,
	)

	let font = (
		sans: "libertinus sans",
		serif: "libertinus serif",
		size: 12pt,
	)

	set text(
		size: font.size,
		font: font.sans,
	)

	let margin = 1in
	set page(
		width: (12.17 * 72 / 26 * font.size) + margin,
		margin: margin,
		height: auto,
	)

	show heading: set text(font: font.serif)

	set par(leading: 0.60em, justify: true)
	show heading: set block(above: 1.4em, below: 1em)

	// See the note on the show rule of `link` in
	// `typst-to-markdown` above.
	show link: it => if type(it.dest) == dictionary {
		if it.dest.type == "abbr" [
			#it.body (#it.dest.title)
		] else {
			panic("invalid type")
		}
	} else {
		it
	}

	align(center, heading(level: 1, title))
	v(12pt)

	body
}

/// The template used when building PDFs.
/// Out of laziness, it uses the preview one for now.
#let typst-to-pdf(title, date) = typst-to-preview(title, date)