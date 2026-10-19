# Write CITATION.cff from DESCRIPTION.
# Usage: Rscript cff.R /path/to/package owner/repo site_url
args <- commandArgs(trailingOnly = TRUE)
pkg <- args[[1]]
repo <- args[[2]]
site_url <- args[[3]]

d <- read.dcf(file.path(pkg, "DESCRIPTION"))[1, ]
clean <- function(x) gsub("\\s+", " ", gsub("'", "", trimws(x)))
# Double-quoted YAML scalar.
yaml_str <- function(x) sprintf('"%s"', gsub('(["\\\\])', "\\\\\\1", x))

authors <- Filter(
  function(p) "aut" %in% p$role,
  eval(parse(text = d[["Authors@R"]]))
)

spdx <- c(
  "MIT + file LICENSE" = "MIT",
  "GPL-2" = "GPL-2.0-only",
  "GPL-3" = "GPL-3.0-only",
  "GPL (>= 2)" = "GPL-2.0-or-later",
  "GPL (>= 3)" = "GPL-3.0-or-later",
  "Apache License (>= 2)" = "Apache-2.0",
  "Apache License 2.0" = "Apache-2.0",
  "LGPL-3" = "LGPL-3.0-only",
  "AGPL-3" = "AGPL-3.0-only"
)
license <- unname(spdx[d[["License"]]])

author_lines <- unlist(lapply(authors, function(p) {
  orcid <- p$comment[["ORCID"]]
  c(
    if (is.null(p$family)) {
      paste0("  - name: ", yaml_str(p$given))
    } else {
      c(
        paste0("  - family-names: ", yaml_str(p$family)),
        paste0("    given-names: ", yaml_str(paste(p$given, collapse = " ")))
      )
    },
    if (!is.null(p$email)) sprintf("    email: %s", p$email),
    if (!is.null(orcid)) sprintf("    orcid: \"https://orcid.org/%s\"", orcid)
  )
}))

abstract <- strwrap(clean(d[["Description"]]), width = 76, prefix = "  ")

lines <- c(
  "cff-version: 1.2.0",
  "message: \"If you use this software, please cite it as below.\"",
  "type: software",
  paste0(
    "title: ",
    yaml_str(paste0(d[["Package"]], ": ", clean(d[["Title"]])))
  ),
  "abstract: >-",
  abstract,
  "authors:",
  author_lines,
  sprintf("version: %s # x-release-please-version", d[["Version"]]),
  sprintf("date-released: %s", format(Sys.Date())),
  if (is.na(license)) {
    sprintf("# license: TODO, SPDX id for \"%s\"", d[["License"]])
  } else {
    sprintf("license: %s", license)
  },
  sprintf("url: \"%s\"", site_url),
  sprintf("repository-code: \"https://github.com/%s\"", repo)
)

writeLines(lines, file.path(pkg, "CITATION.cff"))
