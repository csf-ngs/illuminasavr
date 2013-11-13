
function CyclePlotCtrl($scope, iData) {

  //TODO: add transform function Data => Value e.g. % base at cycle  

  $scope.svgWidth = 512;
  $scope.svgHeight = 400;
  

  $scope.plotTypes = IllP.plotTypesCycle;

  $scope.surfaceTypes = IllP.surfaceTypes;
  $scope.laneTypes = IllP.laneTypes; 
  $scope.swathTypes = IllP.swathTypes;

  $scope.selectSwath = "all";
  $scope.selectSurface = "both";
  $scope.selectLane = "all"; 
  $scope.selectRead = 0; //this option will change start cycle and max cycle! maybe not necessary. not implemented

  $scope.plotType = $scope.plotTypes[0];

  //data properties
  $scope.originalData = [];
  $scope.plotData = [];

  iData.cycleData.async().then(function(cycleData){
      $scope.originalData = cycleData.data;
      $scope.maxTileNr = cycleData.maxTileNr;
      $scope.maxCycle = cycleData.maxCycle;
      $scope.laneTypes = cycleData.laneTypes;
      $scope.swathTypes = cycleData.swathTypes;
      $scope.prepareData();
  });
 

  $scope.extractData = function(originalData, rowIndex, dataColumns, dataColumnKeys){
      var result = new Array(dataColumns.length);
      for(var columnIndex = 0; columnIndex < result.length; columnIndex++){
          var originalDataColumn = dataColumnKeys[dataColumns[columnIndex]];
          result[columnIndex] = originalData[originalDataColumn][rowIndex];
      }
      return { cycle : originalData.cycle[rowIndex], values: result};
  };

  //accumulated data is a hashmap of cycle => array of values in long format
  var addData = function(cycle, values, accumulatedData){
      var stored = accumulatedData[cycle];
      if(stored === undefined){
          var h = {};
          for(var vIndex = 0; vIndex < values.length; vIndex++){
              h[vIndex] = [values[vIndex]];
          }
          accumulatedData[cycle] = h;
      }else{
          for(var vIndex = 0; vIndex < values.length; vIndex++){
              stored[vIndex].push(values[vIndex]);
          }
      } 
  };

  var aggregateData = function(allValues, statFun){
      var means = _.map(_.values(allValues), function(values){ return statFun(values); })
      return { values: means, max: d3.max(means) };
  };

  //aggregates and reformats data in a multi array per cycle
  //TODO: NAN handling possibilities:
  //color for NaN
  //drop of data
  //currenlty set to 0
  var createResult = function(accumulatedData, columnLabels, maxCycle, colours, statFun){
     var resultItems = _.range(columnLabels.length)
     var currentMax = 0;
     var resultData = _.object(resultItems, _.map(resultItems, function(l){ return []; }));
     for(cycleIndex = 1; cycleIndex < maxCycle; cycleIndex++){
         var aggregatedData = aggregateData(accumulatedData[cycleIndex], statFun);
         if(aggregatedData.max > currentMax){
            currentMax = aggregatedData.max;
         }
         for(var vIndex = 0; vIndex < columnLabels.length; vIndex++){
               var value = aggregatedData.values[vIndex];
               if(value === undefined || isNaN(value)){
                  value = 0;
               }
               resultData[vIndex].push(              
               {
                 cycle: cycleIndex,
                 value: value
               }
            );
         }
     } 
     var result = [];
     for(var vIndex = 0; vIndex < columnLabels.length; vIndex++){
          result[vIndex] = { label: columnLabels[vIndex], colour: colours[vIndex], values: resultData[vIndex] };
     }
     return { result: result, max: currentMax };
  };

  //1. data is filtered by selection (lane, surface, swath)
  //2. filtered data is extracted
  //3. extracted data is put into a hash map per cycle
  //3. put data is aggregated (mean) per cycle
  //4. the aggregagted data is stored in plotData
  $scope.prepareData = function(){
     var originalData = $scope.originalData;
     var max = originalData.lane.length; //all columns have same lenght
     var accumulatedData = {};
     var dataColumnKeys = _.keys(originalData);

     for(var rowIndex = 0; rowIndex < max; rowIndex++){
          var selected = IllP.isSelected(originalData, rowIndex, $scope.selectLane, $scope.selectSurface, $scope.selectSwath, "all");
          if(selected){
              var extractedData = $scope.extractData(originalData, rowIndex, $scope.plotType.dataColumns, dataColumnKeys);
              addData(extractedData.cycle, extractedData.values, accumulatedData);
          }
      };
     var statFun = $scope.plotType.statFun !== undefined ? $scope.plotType.statFun : d3.mean;
     var result = createResult(accumulatedData, $scope.plotType.columnLabels, $scope.maxCycle, $scope.plotType.colours, statFun); 
     $scope.plotData = result.result;
     $scope.allMax = result.max;
  };

  $scope.plotRenderer = function(el, data) {
    var marginLeft = 90;
    var marginTop = 25;
    var marginBottom = 25;
    var width = $scope.svgWidth;
    var height = $scope.svgHeight;
    var plotId = 'lineplot';

    var plotData = data;
 
    if(plotData.length == 0){
      return;
    } 

   

   //yRange and y will be redefined for stacked area chart
   //could not make stack work the way I wanted
   var xRange = [1, $scope.maxCycle];
   var yRange = [$scope.allMax, 0];  
   var x = d3.scale.linear().domain(xRange).range([0,width - marginLeft]);
   var yH = height - ( marginTop + marginBottom);
   var y = d3.scale.linear().domain(yRange).range([0, yH]);
    

   var maxSum = function(pd){
        var sums = new Array(pd[0].values.length);
        for(var ci = 0; ci < sums.length; ci++){
           var sum = 0;
           for(var di = 0; di < pd.length; di++){
              sum += pd[di].values[ci].value;
           }
           sums[ci] = sum;
        }
        var maxSum = d3.max(sums);
        return maxSum;
    }

    var createOffSets = function(pd){
        var offsets = _.map(_.range(pd[0].values.length), function(d){ return 0 });
        for(var di = 0; di < pd.length; di++){
           var cd = pd[di];
           _.each(cd.values, function(elem, index){
               var y1 = y(elem.value + offsets[index]);
               var y0 = y(offsets[index]);
               offsets[index] = elem.value + offsets[index];
               elem.y0 = y0;
               elem.y1 = y1;
           });
        }
    };

    var lineFun = d3.svg.line()
         .x(function(d,i){
             return x(d.cycle);
         })
         .y(function(d, i){
            return y(d.value);
         });


    var areaFun = d3.svg.area()
        .x(function(d,i){
             return x(d.cycle);
         })
         .y0(function(d, i){
             return d.y0;
          })
         .y1(function(d, i){
            return d.y1;
         });


    switch($scope.plotType.chartType){
          case "area": plotFun = areaFun; fillFun = function(d, i){
           return d.colour;
         };
         var ms = maxSum(plotData);
         yRange = [ms,0];
         y = d3.scale.linear().domain(yRange).range([0, yH]);
         createOffSets(plotData);
         break;
         default: plotFun = lineFun; fillFun = "none";
   };
 


    el.selectAll("#"+plotId)
                 .data([0])
                 .enter()
                 .append("g")
                 .attr("transform", "translate("+marginLeft+","+marginTop+")")
                 .attr("id", plotId)
                 .append("rect")
                 ;

    var plot = d3.selectAll("#"+plotId);
   
    
    var xAxis = d3.svg.axis()
                  .scale(x)
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
  


    var legend = IllP.createLabels($scope.plotType.columnLabels, $scope.plotType.colours);
    IllP.plotLegend(plot, legend, plotId, width - marginLeft);


    

   var lines = plot.selectAll(".line")
                .data(plotData, function(k, i){ 
                    return k.label;
                });

                lines.exit().remove();

                lines.enter()
                .append("path")
                .attr("class", "line")
                .attr("fill", fillFun)
                .attr("stroke", function(d, i){ return d.colour; })
                .attr("d", function(d,i){ return plotFun(d.values, i); });
                
 
                 lines.transition()
                      .duration(500)
                      .attr("d", function(d,i){ return plotFun(d.values, i); }); 

  };


}



