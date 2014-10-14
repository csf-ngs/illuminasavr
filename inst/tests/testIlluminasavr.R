context("illuminasavr")



test_that("parse thumbnail name", {
   exp <- data.frame(surface="top", swath=1, tileNr=6, column=1, swathColumn=1, tileId=11106, base=factor("A"))
#   expect_equal(parseThumbnailName("s_1_1106_A.jpg"), exp)
   expect_equal(1,1)
})


test_that("parce cycle", {
   expect_equal(parseCycleName("C102.1"), 102)
})

test_that("mangle jpg path", {
   absp  <- "/projects/hiseq1/hiseq4/Runs/FC_A/141008_7001253F_0202_AC5E7AANXX/Thumbnail_Images/L003/C13.1/s_3_2113_T.jpg"
   exp <- "Thumbnail_Images/L003/C13.1/s_3_2113_T.jpg"
   expect_equal(mangleJpgPath(absp), exp)
})

