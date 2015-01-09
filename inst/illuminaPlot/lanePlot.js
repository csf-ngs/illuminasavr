
function LanePlotCtrl($scope, iData ) {

  $scope.svgWidth = 512;
  $scope.svgHeight = 400;

  $scope.plotTypes = IllP.plotTypesLane;

  $scope.surfaceTypes = IllP.surfaceTypes;
  $scope.swathTypes = IllP.swathTypes;

  //selectors 0 means all
  $scope.selectSwath = "all";
  $scope.selectSurface = "both";

  $scope.plotType = $scope.plotTypes[0];
  $scope.plotData = [];

  iData.tileData.async().then(function(tileData){
        $scope.maxLane = tileData.maxLane;
        $scope.originalData = tileData.data;
        $scope.swathTypes = tileData.swathTypes;
        $scope.laneTypes = tileData.laneTypes;
        $scope.prepareData();
  });

  $scope.extractData = function(originalData, rowIndex, dataColumns, dataColumnKeys){
      var result = new Array(dataColumns.length);
      for(var columnIndex = 0; columnIndex < result.length; columnIndex++){
          var originalDataColumn = dataColumnKeys[dataColumns[columnIndex]];
          result[columnIndex] = originalData[originalDataColumn][rowIndex];
      }
      return { lane : originalData.lane[rowIndex], values: result};
  };

  //accumulated data is a hashmap of lane => array of values { all, pf }
  var addData = function(lane, values, accumulatedData){
      var stored = accumulatedData[lane];
      if(stored === undefined){
          stored = [];
          accumulatedData[lane] = stored;
      }     
      stored.push(
              {
                  all : values[0],
                  pf : values[1]
              }); 
  };


  var createResult = function(accumulatedData, maxLane, colours, statFun){
     var result = [];
     var currentMax = 0;
     for(laneIndex = 1; laneIndex <= maxLane; laneIndex++){
         var aggregatedData = statFun( accumulatedData[laneIndex]);
         if(aggregatedData.max > currentMax){
            currentMax = aggregatedData.max;
         }
         result[laneIndex - 1] = aggregatedData;
     } 
     return { result: result, max: currentMax };
  };

  //1. data is filtered by selection (surface, swath)
  //2. filtered data is extracted
  //3. extracted data is put into a hash map per lane
  //3. put data is aggregated per cycle either density or sum
  //4. the aggregagted data is stored in plotData
  $scope.prepareData = function(){
     
     var densities = function(acc){
       var allValues = _.map(acc, function(v){ return v.all; });
       var pfValues =  _.map(acc, function(v){ return v.pf; });
       var max = Math.max(_.max(allValues), _.max(pfValues));
       var density = function(values){
           var kde = science.stats.kde().sample(values); 
           var min = _.min(values);
           var max = _.max(values);
           var stepSize = (max - min)/112;
           var kdest = kde(d3.range(min,max,stepSize));
           var med = science.stats.median(values);
           kdest.median = med;
           return kdest;
       }
       allValuesD = density(allValues);
       pfValuesD = density(pfValues);
       return { all: allValuesD, pf: pfValuesD, max: max };
     };
    
     var sumbar = function(acc){
         var allValues = d3.sum(acc, function(v){ return v.all; });
         var pfValues =  d3.sum(acc, function(v){ return v.pf; });
         var max = Math.max(allValues, pfValues);
         return { all: allValues, pf: pfValues, max: max }; 
     }; 


     var originalData = $scope.originalData;
     var max = originalData.lane.length; //all columns have same lenght
     var accumulatedData = {};
     var dataColumnKeys = _.keys(originalData);

     for(var rowIndex = 0; rowIndex < max; rowIndex++){
          var selected = IllP.isSelected(originalData, rowIndex, "all", $scope.selectSurface, $scope.selectSwath, "all");
          if(selected){
              var extractedData = $scope.extractData(originalData, rowIndex, $scope.plotType.dataColumns, dataColumnKeys);
              addData(extractedData.lane, extractedData.values, accumulatedData);
          }
     };
     switch ($scope.plotType.chartType) {
         case "violin": statFun = densities; break;
         case "bar": statFun = sumbar; break;
     }
     
     var result = createResult(accumulatedData, $scope.maxLane, $scope.plotType.colours, statFun); 
     $scope.plotData = result.result;
     $scope.allMax = result.max;
  };


  var barplot = function(plot, singleData, height, boxwidth, xpos, max, lane, item, colour){
      var pid = liId(lane, item, "p");
      var mid = liId(lane, item, "m");
      var pl = plot.selectAll("#"+pid).data([]).exit().transition().duration(500).style("opacity", 0).remove();
      var pm = plot.selectAll("#"+mid).data([]).exit().transition().duration(500).style("opacity", 0).remove();


      var bid = liId(lane, item, "b");
      var bar = plot.selectAll("#"+bid).data([singleData]);
      

      var y = d3.scale.linear().domain([max, 0]).range([0,height]);
      var h = d3.scale.linear().domain([0, max]).range([0,height]);

      var margin = 0.7;
      var bw = boxwidth/2 * margin;
      var shift = (1 - margin) * boxwidth/2;
      var xp = item == "all" ? shift : shift + bw;

      bar.enter().append("rect")
          .attr("id", bid)
          .attr("fill", colour)
          .attr("fill-opacity", 0.5)
          .attr("x", xpos + xp)
          .attr("y", y(singleData))
          .attr("width", bw)
          .attr("height", h(singleData)); 
      //must set all again because of switch with violin plot  
      bar.transition().duration(500)
          .attr("x", xpos + xp)
          .attr("y", y(singleData))
          .attr("width", bw)
          .attr("height", h(singleData));
          
      bar.exit().remove();

  };

  var liId = function(lane, item, suffix){
      return "lane"+lane+item+suffix;
  }

  var violin = function(plot, singleData, height, boxwidth, xpos, max, lane, item, colour){
      var xvals = _.map( singleData, function(v){ return v[1]; } );
      var maxX = _.max(xvals);
      var medWidth = 6; //width of median bar
      var xRange = [maxX * 1.1, 0];
      var x = d3.scale.linear().domain(xRange).range([0, boxwidth/2]);
      var y = d3.scale.linear().domain([max, 0]).range([0,height]);
      var area = d3.svg.area()
                 .x(function(d){ 
                     return y(d[0]); 
                 })
                 .y1(boxwidth/2)
                 .y0(function(d){ return x(d[1]); }); 
      var pid = liId(lane, item, "p");
      var mid = liId(lane, item, "m");
      var med = liId(lane, item, "b");

      var pl = plot.selectAll("#"+pid).data([singleData]); 
      var pm = plot.selectAll("#"+mid).data([singleData]);
      var bar = plot.selectAll("#"+med).data([singleData]);

     pl.enter().append("path")
          .attr("id", pid)
          .attr("class", "area")
          .attr("fill-opacity", 0.2)
          .attr("fill", colour)
          .attr("d", area);
     
      pm.enter().append("path")
          .attr("id", mid)
          .attr("class", "area")
          .attr("fill-opacity", 0.2)
          .attr("fill", colour)
          .attr("d", area);

      bar.enter().append("rect")
          .attr("id", med)
          .attr("fill", colour)
          .attr("fill-opacity", 0.5)
          .attr("x", xpos + boxwidth/4)
          .attr("y", y(singleData.median) + medWidth/2 )
          .attr("width", boxwidth/2)
          .attr("height", medWidth);
      

      pl.transition().duration(500)
          .attr("d", area);

      pm.transition().duration(500)
          .attr("d", area);

      //must set all again because of barplot
      bar.transition().duration(500)
          .attr("x", xpos + boxwidth/4)
          .attr("y", y(singleData.median) + medWidth/2)
          .attr("width", boxwidth/2)
          .attr("height", medWidth);
      
      pl.attr("transform", "rotate(90,0,0) scale(1,1) translate("+0+","+(-(xpos+boxwidth))+")");
      pm.attr("transform", "rotate(90,0,0) scale(1,-1) translate("+0+","+xpos+")");
  
      pl.exit().remove();
      pm.exit().remove();
      bar.exit().remove();
  
  };

  $scope.plotRenderer = function(el, data) {
    var marginLeft = 90;
	var marginRight = 15;
    var marginTop = 25;
    var marginBottom = 34;
    var width = $scope.svgWidth;
    var height = $scope.svgHeight;
    var pairWidth = 20;
    
    var plotId = 'laneplot';

    var plotData = data;

    el.selectAll("#"+plotId)
                 .data([0])
                 .enter()
                 .append("g")
                 .attr("transform", "translate("+marginLeft+","+marginTop+")")
                 .attr("id", plotId)
                 .append("rect")
                 ;

    if(plotData.length  == 0){
         return;
    };
    var max = d3.max(plotData,function(p){ return p.max; });
    var xRange = [0.5, plotData.length + 0.5];
    var yRange = [max, 0];

    var x = d3.scale.linear().domain(xRange).range([0, width - (marginLeft + marginRight)]);
    var yH = height - ( marginTop + marginBottom);
    var y = d3.scale.linear().domain([max, 0]).range( [0, yH ]);

    var plot = d3.selectAll("#"+plotId);
   
    
    var xAxis = d3.svg.axis()
                  .scale(x)
                  .tickValues(_.range(1, plotData.length+1))
                  .tickFormat(d3.format("d"))
                  .orient("bottom");
   
    var xaxs = plot
             .selectAll(".xaxis")
             .data([xRange]);

       xaxs.enter().append("g")
             .attr("class", "xaxis")
             .attr("transform", "translate(0," + yH + ")");
   
   
        xaxs.transition()
             .duration(500)
             .call(xAxis);
             
    var yAxis = d3.svg.axis()
                .scale(y)
                .orient("left");

    var yaxs = plot
               .selectAll(".yaxis")
               .data([yRange]);
            
        yaxs.enter().append("g")
             .attr("class", "yaxis");


        yaxs.transition()
             .duration(500)
             .call(yAxis);

    IllP.plotLegend(plot, [{ key: "all", colour: "blue", opacity: 0.5 }, { key: "pf", colour: "red", opacity: 0.5 }], plotId, width - (marginLeft + marginRight));

    switch( $scope.plotType.chartType ){
       case "violin": pl = violin; break;
       case "bar" : pl = barplot; break;
    }

    for(var i = 0; i < plotData.length; i++){
        var boxwidth = (width - (marginLeft + marginRight))/(plotData.length);
        var xpos = boxwidth * i;
        pl(plot, plotData[i].all, yH, boxwidth, xpos, max, i, "all", "blue");
        pl(plot, plotData[i].pf, yH, boxwidth, xpos, max, i, "pf", "red");
    }
  
  
  };


}

