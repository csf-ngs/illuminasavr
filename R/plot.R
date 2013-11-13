require("ggplot2")
require("plyr")

# TODO: ggplot2 grid with theme:
# white background, reads are separated by light grey lines
# tick marks only on read boundaries 

folder <- "H0DDBADXX_interop"
correctedIntMetrics <- function(){
  infile <- paste(folder, "/CorrectedIntMetricsOut.bin", sep="")
  d <- parseFile(infile, correctedIntensityMetricsParser2(), TRUE)

  ggplot(d$basecallsCount, aes(x=cycle,y=basecalls.count, colour=channel)) + stat_summary(fun.y="mean",geom="line") + facet_grid(lane ~ .)

  #nr of basecalls
  ggplot(d$basecallsCount , aes(x=factor(cycle),y=basecalls.count, colour=channel)) + geom_boxplot() + facet_grid(lane ~ channel) + ylab("called bases") 
  ggsave("basecallsCount.pdf")

  #intensities
  ggplot(d$averageInt,  aes(x=factor(cycle),y=average.intensity, colour=channel)) + geom_boxplot() + facet_grid(lane ~ channel) + ylab("average intensity")
  ggsave("average_int.pdf")

  ggplot(d$averageIntACalled, aes(x=factor(cycle),y=average.intensity.of.called, colour=channel)) + geom_boxplot() + facet_grid(lane ~ channel) + ylab("average intensity of called")
  ggsave("average_int_called.pdf")

  ggplot(d$SNR, aes(x=factor(cycle), y=SNR)) + geom_boxplot() + facet_grid(lane ~ .) + ylab("SNR")
  ggsave("snr.pdf")



 # ggplot(subset(mcs, measurement="intensity"), aes(x=cycle,y=value, colour=channel)) + stat_summary(fun.y= mean, fun.ymin=function(v){ mean(v)-sd(v)}, fun.ymax=function(v){ mean(v)+sd(v) })

}



errorFile <- function(){
   infile <- "D24J3ACXX_interop/ErrorMetricsOut.bin"
   d <- parseFile(infile, errorMetricsParser3() , TRUE)   
   
   ggplot(d$errorRate, aes(x=factor(cycle),y=error.rate,colour=factor(lane))) + geom_boxplot() + facet_grid(lane ~ .)    
   ggsave("error_rate.pdf")

 #  ggplot(d$errorCount, aes(x=factor(cycle), y=error   
  


}

extractionMetrics <- function(){
    infile <- "D24J3ACXX_interop/ExtractionMetricsOut.bin"
    d <- parseFile(infile, extractionMetricsParser2(), TRUE)
    ggplot(d$fwhm, aes(x=factor(cycle), y=fwhm, colour=channel)) + geom_boxplot() + facet_grid(lane ~ .)  
    ggsave("fwhm.pdf")
    

    ggplot(d$intensity, aes(x=factor(cycle), y=intensity, colour=channel)) + geom_boxplot() + facet_grid(lane ~ channel)
    ggsave("intensity.pdf")

    

}


qualityMetrics <- function(){
   infile <- "D24J3ACXX_interop/QMetricsOut.bin"
   d <- parseFile(infile, qualityMetricsParser4(), TRUE)
   

   #takes long, but string hacks take even longer
   q30 <- ddply(d$qvals, qualityMetricsParser4()$id.vars, function(v){ 
          total <- sum(v$count)
          above <- sum(v[as.integer(v$QScore) > 30,]$count)
          medianQ <- median(rep(as.integer(v$QScore), times=v$count)) #almost identical to limma round(weighted.median)
          data.frame(total=total, q30=above, q1=total-above, ratio=above/total, perc=above/total*100, medianQ=medianQ)              
   })

   ggplot(q30, aes(x=factor(cycle), y=ratio)) + geom_boxplot() + facet_grid(lane ~ .)
   ggsave("boxplot_q30.pdf")

   
   ggplot(q30, aes(x=factor(cycle), y=medianQ)) + geom_boxplot() + facet_grid(lane ~ .)  
   ggsave("boxplot_medianQ.pdf")
  
}


joinTileInfo <- function(){
  #join all tileId/cycle/channel to one big table?
 # fwhm, intensities, densitiy,  

}

tileMetrics <- function(){
    d <- parseFile(tileMet, tileMetricsParser2())
#   crashes R
#    wo <- subset(d, code %in% c(102,103))
#    ratios <- ddply(wo, tileMetricsParser2()$id.vars, function(v){
#         total <- v[v$code == 102]$value
#         pf <- v[v$code == 103]$value
#         data.frame(code=code,ratio=pf/total)
#    },.drop=FALSE)    

    d$tileId <- d$lane * 1e5 + d$tile
    allC <- subset(d, code == 102)
    pfC <- subset(d, code == 103)
    m <- merge(allC, pfC, by="tileId")
    if(nrow(m) != nrow(allC)){
        stop("wrong merge")
    }
    ratios <- m$value.y/m$value.x 
    
    allC$code <- 701
    allC$value <- ratios

    d <- rbind(d, allC)

    ggplot(subset(d, code %in% c(100,101)), aes(x=factor(lane), y=value, color=factor(code))) + geom_boxplot() + ylab("Cluster Density (clusters/mm^2)")
    ggsave("cluster_density.pdf")
 
    ggplot(subset(d, code %in% c(102,103)), aes(x=factor(lane), y=value, fill=factor(code))) + stat_summary(fun.y="sum", geom="bar", position="dodge") + ylab("clusters")
    ggsave("cluster_count.pdf")

    ggplot(subset(d, code == 103), aes(x=swathColumn, y=tileNr,fill=value)) + geom_tile() + facet_grid(. ~ lane)

    ggplot(subset(d, code == 701), aes(x=swathColumn, y=tileNr, fill=value)) + geom_tile() + facet_grid(. ~ lane)

}



