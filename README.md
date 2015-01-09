illuminasavr
============
R functions for parsing of Illumina SAV (sequence analysis viewer) files, plotting with ggplot2 and generating of an ajaxified website

The website allows to interactively looking at the data (see screenshot).
The website now also soft links the Thumbnails_Images folder into the generated folder to be able to view the images.

 
Depends on: 
XML,ggplot2,plyr,reshape2,rjson

Uses:
R,angular.js,d3.js

install
-------
```R
library("devtools")
install_github("illuminasavr", "csf-ngs")
library("illuminasavr")

#generate site in outputfolder
makeSite("/full/path/to/InterOp", "/full/path/to/outputfolder")

#generate site in runfolder
makeSiteInRunfolder("/full/path/to/Runfolder")
```

TODO
----
 - [] check Q30,Q20 data for correctness, its different from illuminas
 - [] table of data
 - [] integrate sample.json
 - [] don't load everything multiple times in the controller

REMARK:
-------
Currently it parses QMetricsOut.bin version 5 files RTA 1.18.64+
There is a parser for QMetricsOut.bin version 4 in the source code.
Just change 

```R
  qmet <- parseFile(qmet, qualityMetricsParser5(), FALSE)
  qmet <- qualityMetricsParser5()$toStats(qmet)

//to

  qmet <- parseFile(qmet, qualityMetricsParser4(), FALSE)
  qmet <- qualityMetricsParser4()$toStats(qmet)
```


screenshot:
-----------

![Screenshot of interactive angular.js app](https://raw.githubusercontent.com/csf-ngs/illuminasavr/master/doc/screenshot.jpg)






