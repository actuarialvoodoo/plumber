context("POST body")

test_that("JSON is consumed on POST", {
  expect_equal(parse_body('{"a":"1"}', content_type = NULL, parsers = make_parser("json")), list(a = "1"))
})

test_that("ending in `==` does not produce a unexpected key", {
  # See https://github.com/rstudio/plumber/issues/463
  expect_equal(parse_body("randomcharshere==", content_type = NULL, parsers = make_parser("query")), list())
})

test_that("Query strings on post are handled correctly", {
  expect_equivalent(parse_body("a=", parsers = make_parser("query")), list()) # It's technically a named list()
  expect_equal(parse_body("a=1&b=&c&d=1", content_type = NULL, make_parser("query")), list(a="1", d="1"))
})

test_that("Able to handle UTF-8", {
  expect_equal(parse_body('{"text":"Ã©lise"}', content_type = "application/json; charset=UTF-8", parsers = make_parser("json"))$text, "Ã©lise")
})

#charset moved to part parsing
test_that("filter passes on content-type", {
  content_type_passed <- ""
  req <- list(
    postBodyRaw = charToRaw("this is a body"),
    HTTP_CONTENT_TYPE = "text/html; charset=testset",
    args = c()
  )
  with_mock(
    parse_body = function(body, content_type = "unknown", parsers = NULL) {
      print(content_type)
      body
    },
    expect_output(postbody_parser(req, make_parser("text")), "text/html; charset=testset"),
    .env = "plumber"
  )
})

# parsers
test_that("Test text parser", {
  expect_equal(parse_body("Ceci est un texte.", "text/html", make_parser("text")), "Ceci est un texte.")
})

test_that("Test yaml parser", {
  skip_if_not_installed("yaml")

  r_object <- list(a=1,b=list(c=2,d=list(e=3,f=4:6)))
  expect_equal(parse_body(charToRaw(yaml::as.yaml(r_object)), "application/x-yaml", make_parser("yaml")), r_object)
})

test_that("Test csv parser", {
  tmp <- tempfile()
  on.exit({
    file.remove(tmp)
  }, add = TRUE)

  r_object <- cars
  write.csv(r_object, tmp, row.names = FALSE)
  val <- readBin(tmp, "raw", 1000)

  parsed <- parse_body(val, "application/csv", make_parser("csv"))
  # convert from readr tibble to data.frame
  parsed <- as.data.frame(parsed, stringsAsFactors = FALSE)
  attr(parsed, "spec") <- NULL

  expect_equal(parsed, r_object)
})

test_that("Test tsv parser", {
  tmp <- tempfile()
  on.exit({
    file.remove(tmp)
  }, add = TRUE)

  r_object <- cars
  write.table(r_object, tmp, sep = "\t", row.names = FALSE)
  val <- readBin(tmp, "raw", 1000)

  parsed <- parse_body(val, "application/tab-separated-values", make_parser("tsv"))
  # convert from readr tibble to data.frame
  parsed <- as.data.frame(parsed, stringsAsFactors = FALSE)
  attr(parsed, "spec") <- NULL

  expect_equal(parsed, r_object)
})

test_that("Test multipart parser", {
  # also tests rds and the octet -> content type conversion

  bin_file <- test_path("files/multipart-form.bin")
  body <- readBin(bin_file, what = "raw", n = file.info(bin_file)$size)
  parsed_body <- parse_body(body,
                            "multipart/form-data; boundary=----WebKitFormBoundaryMYdShB9nBc32BUhQ",
                            make_parser(c("multi", "json", "rds", "octet")))

  expect_equal(names(parsed_body), c("json", "img1", "img2", "rds"))
  expect_equal(parsed_body[["rds"]], women)
  expect_equal(attr(parsed_body[["img1"]], "filename"), "avatar2-small.png")
  expect_equal(parsed_body[["json"]], list(a=2,b=4,c=list(w=3,t=5)))
})


test_that("Test multipart respect content-type", {
  bin_file <- test_path("files/multipart-ctype.bin")
  body <- readBin(bin_file, what = "raw", n = file.info(bin_file)$size)
  parsed_body <- parse_body(body,
                            "multipart/form-data; boundary=---------------------------90908882332870323642673870272",
                            make_parser(c("multi", "tsv")))
  expect_s3_class(parsed_body$sample_name, "data.frame")
})
