require("reshape2") 
require("rjson")
require("XML")
require("stringr")
require("brew")
require("lubridate")
#require("inline") #for date parsing
#require("Rcpp") #for date parsing


#' reads uint16 vector from a raw vector matrix.
#'
#' reads in a uint16 (2 bytes) from a raw vector
#' 
#' @param vec raw vector consiting only of data of interest
readUint16 <- list(
   size=2,
   read=function(vec){ readBin(con=vec, what="integer", size=2, n=length(vec)/2, signed=FALSE, endian="little") } 
)

readFloat <- list(
   size=4, 
   read=function(vec){ readBin(con=vec, what="numeric", size=4, n=length(vec)/4, endian="little") }
)

#todo: this is readInt32 not readUint
readUint32 <- list(
   size=4,  
   read=function(vec){ readBin(con=vec, what="integer", size=4, n=length(vec)/4, endian="little") }
)

#the date is encoded directly from .NET datetime
#currently return vector of NA because it takes to long to parse
readDate <- list(
   size=8,
   read=function(vec){ 
      return (rep(NA, times = length(vec) %/% 8))
      #must remove highest 2 bits because ist the 'kind' of time in .Net
      dim(vec) <- c(8, length(vec) %/% 8 ) 
      hb <- vec[8,] 
      hd <- readBin(hb, what="integer", size=1, n=length(hb), signed=FALSE)
      hdd <- sapply(hd, function(h){ bitAnd(h, 63) })
      hbc <- writeBin(as.integer(hdd), raw())      
      dim(hbc) <- c(4,length(hbc) %/% 4 )
      vec[8,] <- hbc[1,]
      vecr <- vec[8:1,]
      date <- apply(vecr, 2, function(col){ 
            longdate <- as.bigz(paste0("0x",paste0(as.character(col),collapse="")))
            #the original C# date is in 100 ns ticks from 0001-01-01, but R does not have long
            pos <- as.POSIXlt(as.double(div.bigz(longdate, 10000000)), origin = "0001-01-01")      
            #convert sec time back to POSIXlt with  as.POSIXlt(date, origin="1970-01-01")
            as.double(pos)
      }) 
      date
   }
)



#TODO: create CPP function taking raw vector
#for each 8? bytes: remove highest 2 bits

#convert to seconds from epoch; return double vector ?
readDateInline <- list(
   size=8,
   read=function(vec){
      #must remove highest 2 bits because ist the 'kind' of time in .Net
      dim(vec) <- c(8, length(vec) %/% 8 )
      hb <- vec[8,]
      hd <- readBin(hb, what="integer", size=1, n=length(hb), signed=FALSE)
      hdd <- sapply(hd, function(h){ bitAnd(h, 63) })
      hbc <- writeBin(as.integer(hdd), raw())
      dim(hbc) <- c(4,length(hbc) %/% 4 )
      vec[8,] <- hbc[1,]
      vecr <- vec[8:1,]
      date <- apply(vecr, 2, function(col){
            longdate <- as.bigz(paste0("0x",paste0(as.character(col),collapse="")))
            #the original C# date is in 100 ns ticks from 0001-01-01, but R does not have long
            pos <- as.POSIXlt(as.double(div.bigz(longdate, 10000000)), origin = "0001-01-01")
            #convert sec time back to POSIXlt with  as.POSIXlt(date, origin="1970-01-01")
            as.double(pos)
      })
      date
   }
)



#'
#' splits the raw tile integer code into 
#' surface, swath and tileNr
#' 
#' illumina tile code 4 digits
#' 1. surface: 1 top 2 bottom
#' 2. swath 1-3 
#' 3,4 => tile 1-8 currently
#' in addition it creates columns for heatmap
#' swathColumn = column in lane where columns top - columns bottom
#' (row would be tile) 
#' top - swats => bottom swats 
#' tileid = lane + tile == 5 digits unique code for tile
splitTiles <- function(tileCol, laneCol){
   surface <- ifelse(tileCol < 2000, "top", "bottom")
   swath <- (tileCol %/% 100) %% 10
   tile <- tileCol %% 100
   maxSwath <- max(swath)
   swathCol <- (ifelse(tileCol < 2000, 0, maxSwath) + swath) 
   maxSwathCol <- max(swathCol)   
   column <- ((laneCol - 1) * maxSwathCol) + swathCol
   tileId <- laneCol * 1e4 + tileCol 
   df <- data.frame(surface=surface,swath=swath,tileNr=tile,column=column, swathColumn=swathCol,tileId=tileId)  
   colnames(df) <- splitTilesNames()  #just so nobody forgets to update the splitTilesNames function
   df   
}

#'
#' column names added by splitTiles
#' 
splitTilesNames <- function(){
   c("surface", "swath", "tileNr", "column","swathColumn","tileId")
}

#' drops splitTileNames from file
#'
dropSplitTilesNames <- function(df){
   subset(df, select = ! colnames(df) %in% splitTilesNames())
}


#'
#' parses the meta information from an interop file
#'
readMeta <- function(meta){
   meta <- readBin(con=meta, what="integer", size=1, n=2, signed=FALSE, endian="little")
   list(version=meta[1], recordSize=meta[2])
}

#'
#' helper function creating a table of start and end bytes for each entry from the specification
#'
recordIndices <- function(recordSpecification){
   sizes <- sapply(recordSpecification$records[2,], "[[", "size" )
   ends <- cumsum(sizes) 
   starts <- c(1, ends[-length(ends)] + 1)
   data.frame(start=starts, end=ends) 
}

#'
#' tries to extract lane and tile columns from data frame, split tiles and add split columns to data frame
#'
addTiles <- function(df){
   cn <- colnames(df)
   if(length(intersect(c("tile", "lane"), cn)) == 2){
     cols <- subset(df, select=c("tile","lane"))
     st <- splitTiles(as.integer(cols[,1]), as.integer(cols[,2]))
     cbind(df,st)
   }else{
     st
   }
}

#' sorts data frame by lane, tile and optionally cycle
#' 
#'
#'
sortWide <- function(df){
  dfs <- ltc(df)
  so <- do.call(order, dfs)
  df[so,]
}


#'
#' create empty data frame if there is no data available
#'
createNARecords <- function(recordSpecification, long){
   indices <- recordIndices(recordSpecification)   
   colnames <- do.call("c", lapply(1:ncol(recordSpecification$records), function(structIndex){
	  recordSpecification$records[1,structIndex]$columns 
   })) 
   allcols <- c(colnames, splitTilesNames())
   df <- data.frame(sapply(allcols, data.frame))
   colnames(df) <- allcols
   df[0,]
}

#'
#' parses only the data portion of the data without version and length 
#'  
parseRecords <- function(recordsData, recordSpecification, long){
  recordCount <- length(recordsData) %/% recordSpecification$recordSize 
  dim(recordsData) <- c(recordSpecification$recordSize, recordCount)
  indices <- recordIndices(recordSpecification)   
  tdf <- do.call("cbind", lapply(1:ncol(recordSpecification$records), function(structIndex){
      start <- indices[structIndex,1]
      end <- indices[structIndex,2]
      vec <- recordsData[start:end,,drop=TRUE]
      read <- recordSpecification$records[2,structIndex]$reader$read
      values <- read(vec)
      colname <- recordSpecification$records[1,structIndex]$columns
      cdf <- data.frame(values)
      colnames(cdf) <- colname
      cdf
  }))
  tdf <- sortWide(tdf)
  LOG(paste("rows of df: ",nrow(tdf)))
  withTiles <- addTiles(tdf)
  if(long){
    lapply(recordSpecification$long, function(forLong){
        extractNames <- colnames(withTiles)[forLong$columns]
        extractedCols <- subset(withTiles, select=c(recordSpecification$id.vars,extractNames))
        colnames(extractedCols) <- c(recordSpecification$id.vars, forLong$factor)
        molten <- melt(extractedCols, id.vars=recordSpecification$id.vars, variable.name=forLong$variable.name ,value.name=forLong$value.name)     
        molten        
    })
  }else{
    withTiles
  }
}




#'
#' parses the file by a specification to wide format
#'
parseFile <- function(infile, recordSpecification, long=FALSE){
  LOG(paste("parsing: ", infile, long))
  fileSize <- file.info(infile)$size
  if(is.na(fileSize)){
    createNARecords(recordSpecification, long)    
  }
  else{
    con <- file(infile, open="rb")
    raw <- readBin(con=con,what="raw",n=fileSize)
    close(con)
    startAt <- recordSpecification$startAt
    startAt <- if(is.null(startAt)){ 2 }else{ startAt(raw) }
    recordsMetaBin <- raw[1:2]  #byte 0 fileVersionNr byte 1 length of each record
    recordsData <- raw[-c(1:startAt)] #byte 0 fileVersionNr byte 1 length of each record
    # length(raw) %% 206
    recordsMeta <- readMeta(recordsMetaBin)
    parseRecords(recordsData, recordSpecification, long)
  }
}


#' parser for ExtractionMetricsOut.bin
#' 
#' there are no errors for the index read, therefore the wide data frame is
#' shorter than the other datas data frame
#' 
#' Extraction Metrics (ExtractionMetricsOut.bin)
#' Contains extraction metrics such as fwhm scores and raw intensities
#' Format:
#' byte 0: file version number (2)
#' byte 1: length of each record
#' bytes (N * 38 + 2) - (N *38 + 39): record:
#' 2 bytes: lane number (uint16)
#' 2 bytes: tile number (uint16)
#' 2 bytes: cycle number (uint16)
#' 4 x 4 bytes: fwhm scores (float) for channel [A, C, G, T] respectively 
#' 2 x 4 bytes: intensities (uint16) for channel [A, C, G, T] respectively 
#' 8 bytes: date/time of CIF creation
#' Where N is the record index
#'
#' @export
extractionMetricsParser2 <- function(){
   channels <- c("A","C","G","T")
   id.vars <- c("tileId", "tile","lane","cycle","surface","swath","tileNr","column","swathColumn","date")
   columns <- c("lane","tile","cycle",
      paste(c("A","C","G","T"),"fwhm"),
      paste(c("A","C","G","T"),"intensity"),
      "date"
   )
   readers <- list(readUint16,readUint16,readUint16,
              readFloat, readFloat, readFloat, readFloat,
              readUint16, readUint16, readUint16, readUint16,
              readDate) #TODO make date optional because its slow
   records <- rbind(columns, readers)
   forLong <- list(
              fwhm=list(columns=4:7,variable.name="channel",value.name="fwhm",factor=channels),
              intensities=list(columns=8:11,variable.name="channel",value.name="intensity",factor=channels)
              )
   list(
      file = "ExtractionMetricsOut.bin",
      recordSize=38,
      records=records,
      long=forLong,
      id.vars=id.vars
   )
}

#' parser for ErrorMetricsOut.bin
#'
#' Error Metrics (ErrorMetricsOut.bin)
#' Contains cycle error rate as well as counts for perfect reads and read with 1-4 errors
#' Format:
#' byte 0: file version number (3) byte 1: length of each record
#' bytes (N * 30 + 2) - (N *30 + 11): record: 2 bytes: lane number (uint16)
#' 2 bytes: tile number (uint16)
#' 2 bytes: cycle number (uint16)
#' 4 bytes: error rate (float)
#' 4 bytes: number of perfect reads (uint32)
#' 4 bytes: number of reads with 1 error (uint32) 
#' 4 bytes: number of reads with 2 errors (uint32) 
#' 4 bytes: number of reads with 3 errors (uint32) 
#' 4 bytes: number of reads with 4 errors (uint32)
#' Where N is the record index
#'
#' @export
errorMetricsParser3 <- function(){
    id.vars <- c("tileId", "tile","lane","cycle","surface","swath","tileNr","column", "swathColumn")
    columns <- c("lane","tile","cycle","errorRate","reads0", "reads1", "reads2","reads3","reads4")
    readers <- list(readUint16, readUint16, readUint16, readFloat, readUint32, readUint32,readUint32,readUint32,readUint32 )
    records <- rbind(columns, readers)
    forLong <- list(
               errorRate=list(columns=4,variable.name="errorRate",value.name="error.rate",factor="error.rate"),
               errorCount=list(columns=5:9,variable.name="errors",value.name="reads.with.errors",factor=c("0","1","2","3","4"))
    )
    list(
        file = "ErrorMetricsOut.bin",
        recordSize=30,
        records=records,
        long=forLong,
        id.vars=id.vars
    )
}        

#' values are weighted by their index starting with 1
#'
#' the median is taken from limmas weighted median
#'
#' the problem is that the qualities are from Q10 - Q50 and I don't know if mapping them to 1 to 40 is correct
#'
indexWeightedMedian <- function(counts, qualities=seq(1, length(counts))){
	s <- sum(counts)
	if(s == 0){
      return(qualities[1])
    }
	rel <- cumsum(counts)/s
    index <- sum(rel < 0.5)
    if (rel[index + 1] > 0.5){
      qualities[index + 1]
    }else{
      (qualities[index + 1] + qualities[index + 2])/2
    }
}


#' Quality Metrics (QMetricsOut.bin)
#' Contains quality score distribution
#' Format:
#' byte 0: file version number (4)
#' byte 1: length of each record
#' bytes (N * 206 + 2) - (N *206 + 207): record:
#' 2 bytes: lane number (uint16) 
#' 2 bytes: tile number (uint16)
#' 2 bytes: cycle number (uint16)
#' 4 x 50 bytes: number of clusters assigned score (uint32) Q1 through Q50
#' 
#' @export
qualityMetricsParser4 <- function(){
    id.vars <- c("tileId", "tile","lane","cycle","surface","swath","tileNr","column", "swathColumn")
    columns <- c("lane", "tile","cycle", 
                 paste("Q",1:50,sep="")) 
    readers <- list(c(readUint16, readUint16, readUint16, 
                 rep(readUint32, times=50)))
    records <- rbind(columns, readers)
    forLong <- list(
               qvals=list(columns=4:53,variable.name="QScore",value.name="count",factor=1:50)
    )
    toStats <- function(qMet){
          if(nrow(qMet) > 0){
		    mat <- as.matrix(subset(qMet, select=grepl("^Q\\d\\d", colnames(qMet))))
            q30ColIndex <- which(colnames(mat) == "Q30")
            total <- rowSums(mat)
            above <- rowSums(mat[,(q30ColIndex+1):ncol(mat)])
            percQ30 <- above/total*100
            medianQ <- apply(mat, 1, indexWeightedMedian) # <- this is slow maybe speed up somehow 
            qs <- data.frame(percQ30=above/total*100, medianQ=medianQ)
            dfs <- data.frame(subset(qMet, select=c("lane","tile","cycle")), qs)
            addTiles(dfs)
		  }else{
             allcols <- c("lane","tile","cycle","percQ30", "medianQ",splitTilesNames())
			 df <- data.frame(sapply(allcols, data.frame))
		     colnames(df) <- allcols
			 df[0,]
	      }
    }          
    list(
        file = "QMetricsOut.bin",
        recordSize=206,
        records=records,
        long=forLong,
        id.vars=id.vars,
        toStats=toStats
    )
}

#' Quality Metrics (QMetricsOut.bin)
#' Contains quality score distribution
#' Format:
#' byte 0: file version number (5)
#' byte 1: length of each record
#' 23 bytes of unknown function
#' bytes (N * 206 + 2) - (N *206 + 207): record:
#' 2 bytes: lane number (uint16)
#' 2 bytes: tile number (uint16)
#' 2 bytes: cycle number (uint16)
#' 4 x 50 bytes: number of clusters assigned score (uint32) Q1 through Q50
#'
#' @export
qualityMetricsParser5 <- function(){
    id.vars <- c("tileId", "tile","lane","cycle","surface","swath","tileNr","column", "swathColumn")
    columns <- c("lane", "tile","cycle",
                 paste("Q",1:50,sep=""))
    readers <- list(c(readUint16, readUint16, readUint16,
                 rep(readUint32, times=50)))
    records <- rbind(columns, readers)
    forLong <- list(
               qvals=list(columns=4:53,variable.name="QScore",value.name="count",factor=1:50)
    )
    toStats <- function(qMet){
          if(nrow(qMet) > 0){
            mat <- as.matrix(subset(qMet, select=grepl("^Q\\d\\d", colnames(qMet))))
            q30ColIndex <- which(colnames(mat) == "Q30")
            total <- rowSums(mat)
            above <- rowSums(mat[,(q30ColIndex+1):ncol(mat)])
            percQ30 <- above/total*100
            medianQ <- apply(mat, 1, indexWeightedMedian) # <- this is slow maybe speed up somehow
            qs <- data.frame(percQ30=above/total*100, medianQ=medianQ)
            dfs <- data.frame(subset(qMet, select=c("lane","tile","cycle")), qs)
            addTiles(dfs)
          }else{
             allcols <- c("lane","tile","cycle","percQ30", "medianQ",splitTilesNames())
             df <- data.frame(sapply(allcols, data.frame))
             colnames(df) <- allcols
             df[0,]
          }
    }
    list(
        file = "QMetricsOut.bin",
        recordSize=206,
        records=records,
        long=forLong,
        id.vars=id.vars,
        toStats=toStats,
        startAt=startBytesQualityBin
    )
}

#' lower boundary of quality score bins
#'
lowerQualityBoundary <- function(binCount){
   4 - (4+binCount-1)
}

#' upper boundary of quality score bins
#'
upperQualityBoundary <- function(binCount){
  (4+binCount) - (4+2*binCount-1)
}

#' remapped scores of quality score bins
#' 
#'
remappedQualityBins <- function(binCount){
   (4+2*binCount) - (4+3*binCount-1)
}


#' number of binning byte info
#'
#' 
qualityBinByteCount <- function(binCount){
   lower <-  4 - (4+binCount-1)
   upper <- (4+binCount) - (4+2*binCount-1)
   remapped <- (4+2*binCount) - (4+3*binCount - 1)
   lower + upper + remapped 
}

#' gets raw data, returns how many bytes to skip
#'  
#' 
#' 
startBytesQualityBin <- function(raw){
    withBinning <- as.integer(raw)[3]  
    if(withBinning == 1){
       binNum <- as.integer(raw)[4]
       binNum * 3 + 4  
    } else {
       3
    }
}


#' parses corrected Intensity Metrics file
#'
#' Corrected Intensity Metrics (CorrectedIntMetricsOut.bin)
#' Contains base call metrics
#' Format:
#' byte 0: file version number (2)
#' byte 1: length of each record
#' bytes (N * 48 + 2) - (N *48 + 49): record:
#' 2 bytes: lane number (uint16)
#' 2 bytes: tile number (uint16)
#' 2 bytes: cycle number (uint16)
#' 2 bytes: average intensity (uint16)
#' 2 bytes: average corrected int for channel A (uint16)
#' 2 bytes: average corrected int for channel C (uint16)
#' 2 bytes: average corrected int for channel G (uint16)
#' 2 bytes: average corrected int for channel T (uint16)
#' 2 bytes: average corrected int for called clusters for base A (uint16)
#' 2 bytes: average corrected int for called clusters for base C (uint16)
#' 2 bytes: average corrected int for called clusters for base G (uint16)
#' 2 bytes: average corrected int for called clusters for base T (uint16)
#' 20 bytes: number of base calls (float) for No Call and channel [A, C, G, T] respectively
#' 4 bytes: signal to noise ratio (float)
#'
#' @export
correctedIntensityMetricsParser2 <- function(){
   id.vars <- c("tileId", "tile","lane","cycle","surface","swath","tileNr","column","swathColumn")
   channels <- c("A","C","G","T")
   columns <- c("lane","tile","cycle","averageInt",
                     "averageIntA", "averageIntC", "averageIntG","averageIntT",
                    "averageIntACalled","averageIntCCalled","averageIntGCalled","averageIntTCalled",
                    "basecallsNrNo","basecallsNrA","basecallsNrC","basecallsNrG","basecallsNrT",
                    "SNR")
    readers <- list(readUint16, readUint16, readUint16, readUint16,
                    readUint16, readUint16, readUint16, readUint16,
                    readUint16, readUint16, readUint16, readUint16,
                    readUint32, readUint32, readUint32,  readUint32, readUint32,
                    readFloat)
    records <- rbind(columns, readers)
    forLong <- list(averageInt=list(columns=4:8,variable.name="channel",value.name="average.intensity",factor=c("all",channels)),
                    averageIntCalled=list(columns=9:12,variable.name="channel",value.name="average.intensity.of.called",factor=channels),
                    basecallsCount=list(columns=13:17,variable.name="channel",value.name="basecalls.count",factor=c("0",channels)),
                    SNR=list(columns=18,variable.name="ratio",value.name="SNR",factor="SNR")
     )
    list(
        file = "CorrectedIntMetricsOut.bin",
        recordSize=48,
        records=records,
        long=forLong,
        id.vars = id.vars
    )
}


#' Tile Metrics (TileMetricsOut.bin)
#' Contains aggregate or read metrics by tile
#' Format:
#' byte 0: file version number (2)
#' byte 1: length of each record
#' bytes (N * 10 + 2) - (N *10 + 11): record: 
#' 2 bytes: lane number (uint16)
#' 2 bytes: tile number (uint16)
#' 2 bytes: metric code (uint16)
#' 4 bytes: metric value (float)
#' Where N is the record index and possible metric codes are: 
#' code 100: cluster density (k/mm2)
#' code 101: cluster density passing filters (k/mm2)
#' code 102: number of clusters
#' code 103: number of clusters passing filters code 
#' (200 + (N – 1) * 2): phasing for read N 
#' code (201 + (N – 1) * 2): prephasing for read N 
#' code (300 + N – 1): percent aligned for read N 
#' code 400: control lane
#'
#' is already in long format
#' toWide gives wide format 
#' additional columns:
#' 
#' value.150: %cluster pf 
#'
#' @export
tileMetricsParser2 <- function(){
   id.vars <- c("tileId", "tile","lane","surface","swath","tileNr","column","swathColumn")
   columns <- c("lane", "tile", "code", "value")
   readers <- list(readUint16, readUint16, readUint16, readFloat)
   records <- rbind(columns, readers)
   forLong <- list()
   wideDataColumns <- c("value.100","value.101","value.102","value.103")  

   toWide <- function(qmet){
      checkAddCol <- function(nm, df){
          if(sum(grepl(nm,colnames(df))) > 0){
             df
		  }else{
		     df[nm] <- NA
	         df
		  }
      }
	  if(nrow(qmet) > 0){
	      suppressWarnings(wide <- reshape(qmet, idvar=id.vars, timevar="code", direction="wide")) #code 400 in all lanes
		#  wide$value.150 <- (wide[,'value.103']/wide[,'value.102'])*100
          wideId <- wide[,1:(length(id.vars))]
          wideDat <- wide[,(length(id.vars)+1):ncol(wide)]
          for(col in wideDataColumns){
			  wideDat <- checkAddCol(col, wideDat)
		  }
		  cnw <- as.integer(gsub("value.","",colnames(wideDat)))
          cnwo <- order(cnw)
          wideSorted <- data.frame(wideId, wideDat[,cnwo])
          wideSorted
		}else{
          allcols <- c(id.vars, wideDataColumns)
	      df <- data.frame(sapply(allcols, data.frame))
		  colnames(df) <- allcols
		  df[0,]      
	    }
  }
   
   
   list(
        file = "TileMetricsOut.bin",
        recordSize=10,
        records=records,
        long=forLong,
        id.vars=id.vars,
        toWide=toWide
   )

}

#'
#'
#' checks sorted frames for identical lane,tile,cycle order
#'
checkLTC <- function(df1, df2){
     l1 <- ltc(df1)
     l2 <- ltc(df2)
     if(nrow(l1) != nrow(l2)){
         err <- paste("error: different row count", nrow(l1), nrow(l2))
         stop(err)
     }
     if(any(colnames(l1) != colnames(l2)) | (length(colnames(l1)) != 3)){
         err <- paste("error: column names not correct:", colnames(l1), colnames(l2), sep=" ",collapse="")
         stop(err)
     }
     if(any(l1 != l2)){
         diffs <- which(ltc(df1) != ltc(df2))
         err <- paste("error: different sort order!", diffs[1:10], "..." )
         stop(err)
     }
}

#'
#'
#' logger hack to be replaced
#' TODO find logging library
#'
LOG <- function(st){
  print(paste(now(), st))
}

#'
#' extracts lane,tile,cycle from data frame
#'
#'
ltc <- function(df){ subset(df, select = colnames(df) %in% c("lane","tile","cycle")) }

#'
#'  cbinds  lane,tile,cycle sorted data frame
#'  drops lane,tile,cycle from 2. data frame
cbindLTC <- function(a, b){
    bd <- subset(b, select = ! colnames(df) %in% c("lane","tile","cycle"))
    cbind(a, bd)
}

#' #####
#  I GAVE UP ON JOIN because I think only files within themselve are consistent!
#' e.g. extraction metrics are advanced in content during RTA
#'
#' #### 
#' this code is not used anymore and serve just documentation 
#' will be removed
#' joins lane,tile,cycle sorted wide data frames on lane tile cycle combinations
#' has sanity check for identical values in lane, tile, cycle columns
#'
#' because error values don't exist for the index read, will be filled with NA  
#' 
#'
#' TODO: log errors, make error visible in UI somehow error.json file? 
#'
#' @export
joinLaneTileCycle <- function(a, b, allowOuter=FALSE){
   LOG(paste("joining "))
   if(allowOuter){
      checkLTC(a[1:nrow(b),], b)
      missing <- ltc(a[(nrow(b)+1):nrow(a)])
      nam <- matrix(data=0,nrow=nrow(missing),ncol=ncol(b))
      missingdf <- data.frame(missing, nam)
      colnames(missingdf) <- c(colnames(missing), colnames(b))
      cbindLTC(a, rbind(b, missingdf))
   }else{
      checkLTC(a, b)
      cbindLTC(a,b) 
   }
}

#' we allow outer joins
#' 0 instead of NA is confusing
#' downstream programs should be aware that there is not data for this point
#'
#' @export
joinLaneTileCycle <- function(a,b){
  merged <- merge(dropSplitTilesNames(a),dropSplitTilesNames(b),by.x=c("lane","tile","cycle"), by.y=c("lane","tile","cycle"), all=TRUE)
#  merged[is.na(merged)] <- 0
  merged
}



#' creates illuminaMetrics class
#' TODO: put versioned parsers behind version independent facade delegating to versioned parsers
#'
#'
#'
#' @export
parseMetricsWide <- function(path, version="newest"){
  corrInt <- file.path(path, "CorrectedIntMetricsOut.bin")
  corrInt <- parseFile(corrInt, correctedIntensityMetricsParser2(), FALSE)
  
  errMet <- file.path(path, "ErrorMetricsOut.bin")
  errMet <- parseFile(errMet, errorMetricsParser3() , FALSE)

  extMet <- file.path(path, "ExtractionMetricsOut.bin")
  extMet <- parseFile(extMet, extractionMetricsParser2(), FALSE)
  
  qmet <-  file.path(path, "QMetricsOut.bin")
  qmParser <- if(version != "newest"){ qualityMetricsParser4()  }else{ qualityMetricsParser5() }

  qmet <- parseFile(qmet, qmParser, FALSE)
  qmet <- qmParser$toStats(qmet) 

  tileMet <- file.path(path, "TileMetricsOut.bin")
  tileMet <- parseFile(tileMet, tileMetricsParser2())
  tileMet <- tileMetricsParser2()$toWide(tileMet)
   
  #list(correctedInt=corrInt, error=errMet, extraction=extMet, q=qmet, tile=tileMet) 
  
  combined <- joinLaneTileCycle(extMet, corrInt)
  combined <- joinLaneTileCycle(combined, qmet)
  combined <- joinLaneTileCycle(combined, errMet)
  combined <- combined[!is.na(combined$lane),]
  combined <- if(nrow(combined) > 0){ addTiles(combined)  }else{ 
      spl <- data.frame(sapply(splitTilesNames(), data.frame))
	  colnames(spl) <- splitTilesNames()
      cbind(combined,spl[0,])
  }
  corrCycle <- if(nrow(corrInt) > 0){
      max(corrInt$cycle)
  }else{ 1 }

  extCycle <- if(nrow(extMet) > 0){
      max(extMet$cycle)
  }else{ 1 }

  rta <- list(RTA=list(extractedCycle=extCycle,correctedCycle=corrCycle))

#  nrows <- c(nrow(extMet), nrow(corrInt), nrow(qmet), nrow(errMet)) 
#  if(max(nrows) != nrow(combined)){ //is allowed now because of incomplete data during run
#    err <- paste("problem with join of wide frames :", nrows)
#    stop(err)
#  }
  
  list(cycleMetrics=combined,tileMetrics=tileMet,rta=rta)

}

#'
#'
#' TODO: write method
#'
#' @export
parseMetricsLong <- function(path){


}

#' parse thumbnail name
#'
#' 
#'  s_1_1106_A.jpg 
#'
parseThumbnailName <- function(name){
   m <- str_match(name, "s_(\\d)_(\\d{4})_(\\w).jpg")
   if(length(m) == 4){   
      tiles <- as.integer(m[3])
      lane <- as.integer(m[2])
      t <- splitTiles(tiles, lane)
      b <- m[4] 
      data.frame(t,base=b)
   } else {
     NA
   }
}



#' parse cycel name
#'
#'
parseCycleName <- function(name){
   m <- str_match(name, "C(\\d*)\\.(\\d*)")
   if(length(m == 3)){
     as.integer(m[2])
   } else {
     NA
   }
}



generateTileNames <- function(surfaceCount, swathCount, tileCount){
   tiles <- 1:tileCount
   swaths <- 1:swathCount
   surfaces <- 1:surfaceCount
      

}

#' mangles absolut jpg path to a relative path
#' to it can be served 
#'
#'
mangleJpgPath <- function(jpgs){
   str_extract(jpgs, "Thumbnail_Images/.*")   
}

#' gets the thumbnails in dir
#'
#'
parseThumbnailFiles <- function(cycleDir){
   jpgs <- dir(cycleDir, "s_\\d_\\d*_\\w.jpg", full.names=TRUE)
   cycle <- parseCycleName(basename(cycleDir))
   tiles <- do.call("rbind", lapply(basename(jpgs), parseThumbnailName))
   mangledPath <- mangleJpgPath(jpgs)
   tiles$path <- mangledPath
   tiles$cycle <- cycle
   tiles
}



#' parse lane img folder
#' 
#' 
parseLaneThumbnail <- function(path){
   cycleDirs <- dir(path, "C\\d*\\.\\d*", full.names=TRUE)
   cycles <- sapply(basename(cycleDirs), parseCycleName)
   allCycles <- do.call("rbind", lapply(cycleDirs, parseThumbnailFiles))
   allCycles  
}



#' parse all lane folders
#'
#'
parseThumbnailNames <- function(path){
   laneDirs <- dir(path, "L\\d",full.names=TRUE)
   allLanes <- do.call("rbind", lapply(laneDirs, parseLaneThumbnail))
   allLanes
}

#' writes all thumbnail file names and paths into a json file
#'
#'
writeThumbnailNames <- function(thumbPath, outputPath){
   thumbs <- parseThumbnailNames(thumbPath)
   write.json(thumbs, file.path(outputPath, "illuminaPlot", "data", "thumbnails.json"))
}

#' read images in one cycle folder
#' 
#'
readImagesInCycleFolder <- function(path){
   images <- dir(path, "s_.*jpg", full.names=TRUE)  
   wNA <- do.call("rbind", lapply(basename(images), parseThumbnailName))
   wNA <- cbind(wNA, path=images)
   cycle <- parseCycleName(basename(path))
   imgdf <- wNA[!is.na(wNA$tileId),]
   imgdf$cycle <- cycle
   imgdf
}

#'
#' TODO: should be an metrics object method
#'
#' @export
metricsToJson <- function(metrics, path){
   LOG(paste("writing metrics: ",path))
   write.json(metrics$cycleMetrics, file.path(path, "cycleMetrics.json"))
   write.json(metrics$tileMetrics, file.path(path, "tileMetrics.json"))
   write.json(metrics$rta, file.path(path, "status.json"))
}


#' writes data frame to file as JSON
#'
#' @export
write.json <- function(df, path){
   sink(path)
   cat(toJSON(df))
   sink()
}

#' parses runParameters.xml
#' gets RTA version
#'
#' @export
parseRunParameters <- function(path){
  if(file.exists(path)){
    x <- xmlParse(path)
    version <- xpathSApply(x,"//RTAVersion",xmlValue) 
    #hiseq:
    cloudRunId <-  xpathSApply(x,"//RunId",xmlValue)
    #miseq:
    if(length(cloudRunId) == 0){
       cloudRunId <- xpathSApply(x,"//CloudRunId",xmlValue)
    }
    experimentName <- xpathSApply(x,"//ExperimentName",xmlValue)
    templateCycleCount <- xpathSApply(x,"//TemplateCycleCount", xmlValue) 
    bay <- xpathSApply(x,"//FCPosition", xmlValue)
    instrument <- xpathSApply(x,"//ScannerID", xmlValue)
    runNr <- xpathSApply(x,"//ScanNumber", xmlValue)
    flowcell <- xpathSApply(x,"//Barcode",  xmlValue) #WTF?
    list(version=version,cloudRunId=cloudRunId,experimentName=experimentName,
        templateCycleCount=as.integer(templateCycleCount),bay=bay,instrument=instrument,
        runNr=as.integer(runNr),flowcell=flowcell)
  } else {
    list()
  }
}


#' basespaceURL 
#' https://basespace.illumina.com/run/${id}/${exp}
#' /charts optional
#'
basespaceUrl <- function(runParameters){
   if(!is.null(runParameters$cloudRunId) & !is.null(runParameters$experimentName)){
     paste("https://basespace.illumina.com/run/", runParameters$cloudRunId, "/", runParameters$experimentName, sep="")
   } else {
     ""
  }
}

#' reads cycle times into table
#'
#' @export
parseCycleTimes <- function(path){
  if(file.exists(path)){
     ct <- read.table(path, header=TRUE, sep="\t", strings=FALSE)
     dt <-  mdy_hms(paste(ct$Date,ct$Time))     
     ct$dateTime <- dt  
     ct
  } else {
     NULL
  }
}

#' statistics on cycle times
#'
#' @export
cycleTimesStats <- function(cycleTimes){
  secondsPerCycle <- ddply(cycleTimes, .(Cycle), summarize, seconds=lubridate::interval(dateTime[1],dateTime[4]) ) 
  runLength <- lubridate::interval(cycleTimes$dateTime[1],cycleTimes$dateTime[nrow(cycleTimes)]) 
  list(secondsPerCycle=secondsPerCycle,runLength=runLength,meanSecondsPerCycle=mean(secondsPerCycle$seconds))
}

#' run folders by date 
#' 
#' fromTo: lubridate::interval(lubridate::dmy("31/3/2015"),lubridate::ymd("2016/4/17"))
#'
#' @export
runFoldersInInterval <- function(paths, fromTo){
   runFolders <- str_detect(paths, "\\d{6}_\\w{8}_\\d{4}_\\w{10}")
   folders <- paths[runFolders]
   dates <- ymd(unlist(lapply(strsplit(basename(folders), "_"), function(folder){ folder[[1]][1] })))
   ins <- dates %within% fromTo
   folders[ins]
}

#' reads all metadata from folder
#'
#' @export
allMetaFromFolder <- function(path){
  rppath <- if(file.exists(paste(path, "RunParameters.xml",sep="/"))){
               paste(path, "RunParameters.xml",sep="/")
            } else {
               paste(path, "runParameters.xml",sep="/")
            } 
  rp <- parseRunParameters(rppath)
  ri <- parseRunInfo(paste(path, "RunInfo.xml", sep="/"))
  ct <- parseCycleTimes(paste(path, "/Logs/CycleTimes.txt",sep=""))
  cts <- if(! is.null(ct)){ cycleTimesStats(ct) }else{ NULL }
  list(runParameters=rp, runInfo=ri, cycleTimes=ct, cycleTimesStats=cts) 
}

#' parses the run info
#'
#' @export
parseRunInfo <- function(path){
   if(file.exists(path)){
       x <-  xmlParse(path)
	   options(stringsAsFactors=FALSE)
	   reads <- do.call(rbind.data.frame,lapply(getNodeSet(x, "//Read"), function(r){ t(data.frame(xmlAttrs(r))) }))
	   reads$Number <- as.integer(reads$Number)
	   reads$NumCycles <- as.integer(reads$NumCycles)
       totalCycles <- sum(reads$NumCycles)
	   flowcell <- xmlValue(getNodeSet(x,"//Flowcell")[[1]])
       instrument <- xmlValue(getNodeSet(x,"//Instrument")[[1]])
       runDate <- xmlValue(getNodeSet(x,"//Date")[[1]])
       runDate <- ymd(runDate)
       lay <- getNodeSet(x, "//FlowcellLayout")
       layout <- xmlAttrs(lay[[1]])
       layoutN <- as.integer(layout)
       names(layoutN) <- names(layout)
       rapid <- if(layoutN['LaneCount'] == 2){ "rapid" }else{ "HO" }
       PE <- if(nrow(subset(reads, IsIndexedRead == "N")) == 2){ "PE" }else{ "SR" }      
       rl <- cut(reads[1,]$NumCycles, breaks=c(0,52,80,103,130,160,220,310,1000), labels=c(50,75,100,125,150,200,300,1000))
       modus <- paste(PE,":",rl,sep="")
       list(flowcell=flowcell, totalCycles=totalCycles, instrument=instrument, reads=reads, layout=layoutN, PE=PE, rl=rl, modus=modus, rapid=rapid, date=runDate)	    
   } else {
      list(flowcell="NA",totalCycles=0, instrument="NA", reads=data.frame(Number=NA,NumCycles=NA,IsIndexedRead=NA), layout=NA, PE=NA, rl=NA, modus=NA, rapid=NA, date=NA)
   } 
}


#' sets data/status.json to last cycle
#' because MiSeq has different format which crashes metrics parsing, in order to see pictures
#' call this function
#' 
#' {"RTA":{"extractedCycle":16,"correctedCycle":1}}
#'
#'
#' @export
setStatusFinished <- function(runFolder){
   outputPath <- file.path(runFolder, "InterOp")
   runInfo <- parseRunInfo(file.path(runFolder, "RunInfo.xml"))
   tot <- runInfo$totalCycles   
   rta <- list(RTA=list(extractedCycle=tot,correctedCycle=tot))
   write.json(rta, file.path(runFolder, "illuminaPlot", "data", "status.json"))
}


#' creates html site from input somewhere on the file system
#'
#' force: create runfolder again
#'
#' @export
makeSite <- function(inputFolder, outputPath, force=FALSE){
  
   thumbnailstatus <- file.path(outputPath, "illuminaPlot", "data", "thumbs.status.json") 

   outdata <- file.path(outputPath, "illuminaPlot", "data")

   if(! file.exists(outdata) | force){
      base <- system.file('illuminaPlot', package='illuminasavr')
      file.copy(base, outputPath, recursive=TRUE)
      dir.create(outdata, showWarnings = FALSE) #don't know why this does not get copied
      runInfo <- parseRunInfo(file.path(outputPath, "RunInfo.xml"))
      write.json(runInfo, file.path(outputPath, "illuminaPlot", "data", "runInfo.json"))
      runPar <- parseRunParameters(file.path(outputPath, "runParameters.xml")) 
      bspurlnc <- basespaceUrl(runPar)
      bspurl <- paste(bspurlnc, "/charts", sep="")
      runPar$baseSpaceUrl <- bspurlnc
      write.json(runPar, file.path(outputPath, "illuminaPlot", "data", "runParameters.json")) 
      brew(file.path(base, "index.html"), file.path(outputPath, "illuminaPlot", "index.html"))
   }
   
   thumbs <- file.path(outputPath, "illuminaPlot", "Thumbnail_Images")
   orig <- file.path(outputPath, "Thumbnail_Images")
   if(file.exists(outdata) && file.exists(orig) && !file.exists(thumbs)){
        LOG(paste("linking thumbnails"))
        cmd <- paste("ln -s", orig, thumbs)
        system(cmd  , ignore.stdout = TRUE, ignore.stderr = TRUE)
   } else {
       LOG(paste("not linking thumbnails: ", file.exists(outdata) , file.exists(orig) , file.exists(thumbs)))
   }
   #always set status.json to maximum, but let it be overwritten if parseMetricsWide succeeds. Important for thumbnail looking on miseq
   setStatusFinished(dirname(inputFolder)) #dirname is a bit stupid, but inputFolder is runFolder+/+InterOp
   wide <- parseMetricsWide(inputFolder)
   metricsToJson(wide, outdata)
   LOG(paste("done making site: ", outputPath))
}

#' creates a html site within the Run Folder
#'
#' @export
makeSiteInRunfolder <- function(runFolder, force=FALSE){
   LOG(paste("parsing runfolder", runFolder))
   if(! file.exists(runFolder)){
      msg <- paste("runfolder not accessible", runFolder)
	  LOG(msg)
	  stop(msg)	  
   }
   makeSite(file.path(runFolder, "InterOp"), runFolder, force)
}




