illuminasavr
============
R functions for parsing of Illumina SAV (sequence analysis viewer) files, plotting with ggplot2 and generating of an ajaxified website
 
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



