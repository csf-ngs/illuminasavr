context("illuminasavr")



test_that("parse thumbnail name", {
   exp <- data.frame(surface="top", swath=1, tileNr=6, column=1, swathColumn=1, tileId=11106, base=factor("A"))
   expect_equal(parseThumbnailName("s_1_1106_A.jpg"), exp)
})


test_that("parce cycle", {
   expect_equal(parseCycleName("C102.1"), 102)
})




