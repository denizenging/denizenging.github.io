#import "@local/pub-util:0.0.0": *

#let template(
	time: none,
	title: none,
	..args,
) = {
	if title == none {
		panic("no title")
	}

	if time == none or time.len() != 2 {
		panic("no time")
	}

	let building = "building" in sys.inputs
	let now = if building {
		parse-datetime(sys.inputs.now)
	}

	let info = if building {
		let paths = sys.inputs.path.split("/").slice(-3)

		let ret = (:)
		let year = paths.at(-3)
		if regex("^\d+$") in year {
			ret.insert("year", int(year))
		}

		let month-day = paths.at(-2)
		if regex("^\d{4}$") in month-day {
			ret.insert("month", int(month-day.slice(0, 2)))
			ret.insert("day", int(month-day.slice(2)))
		}

		ret.insert("lang", parse-lang(paths.at(-1)))
		ret
	}

	let lang = if building {
		lang-to-lang-region(info.lang)
	}

	let date = if building {
		let ret = datetime(
			year: info.year,
			month: info.month,
			day: info.day,
			hour: time.at(0),
			minute: time.at(1),
			second: 00,
		)
		if ret > now {
			panic("can't create future posts")
		}
		ret
	}

	if not building {
		typst-to-preview(title, none)
		return
	}

	building = sys.inputs.building
	if building == "md" {
		let frontmatter = (
			title: title,
			// We set two dates because `date` is used by pandoc in the
			// format specified down below, but I also want to include
			// the time I have written the document. So we use `date`
			// for pandoc only, and create a new date `datetime`, which
			// is used by Hugo in the frontmatter date formats (see
			//  `hugo.yml`).
			datetime: date.display(
				"[year]-[month]-[day]T[hour]:[day]:[second]Z",
			),
			// The following are solely for pandoc to convert to epubs. 
			// The `title` is also used by pandoc, but not solely.
			// It is also used for Hugo. 
			lang: info.lang,
			date: date.display("[year]-[month]-[day]"),
		)
		let named = args.named()
		for k in ("lastmod", "categories", "tags", "description", "summary", "keywords") {
			if k in named {
				frontmatter.insert(k, named.at(k))
			}
		}

		typst-to-markdown(frontmatter: frontmatter)
	} else if building == "pdf" {
		typst-to-pdf(title, date)
	} else {
		panic("Unsupported format: " + building)
	}
}