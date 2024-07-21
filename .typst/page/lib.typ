#import "@local/pub-util:0.0.0": *

#let template(
	title: none,
	description: none,
	license: "CC BY-NC-ND",
	reading-time: false,
	comments: false,
	menu: none,
	links: none,
	layout: none,
	outputs: none,
) = {
	if title == none {
		panic("no title")
	}

	let building = "building" in sys.inputs
	let info = if building {
		let filename = sys.inputs.at("path").split("/").at(-1)
		(lang: parse-lang(filename))
	}

	let lang = if building {
		lang-to-lang-region(info.lang)
	}

	let doc = (
		title: title,
	)

	if not building {
		typst-to-preview(title, none)
		return
	}

	building = sys.inputs.building
	if building == "md" {
		let frontmatter = (
			title: title,
			// The `lang` here is solely for pandoc to convert to epubs. 
			// The `title` is also used by pandoc, but not solely.
			// It is also used for Hugo. 
			lang: info.lang,
		)
		if description != none {
			frontmatter.insert("description", description)
		}
		if reading-time != none {
			frontmatter.insert("readingTime", reading-time)
		}
		if license != none {
			frontmatter.insert("license", license)
		}
		if comments != none {
			frontmatter.insert("comments", comments)
		}
		if menu != none {
			frontmatter.insert("menu", (main: (
				weight: menu.at(0),
				params: (icon: menu.at(1)),
			)))
		}
		if links != none {
			frontmatter.insert("links", links.map(x => (
				title: x.at(0),
				description: x.at(1),
				website: x.at(2),
				image: x.at(3),
			)))
		}
		if layout != none {
			frontmatter.insert("layout", layout)
		}
		if outputs != none {
			frontmatter.insert("outputs", outputs)
		}

		typst-to-markdown(frontmatter: frontmatter)
	} else if building == "pdf" {
		typst-to-pdf(title, none)
	} else {
		panic("Unsupported format: " + building)
	}
}