
function CycleHeatCtrl($scope, iData) {
  $scope.svgWidth = 512;
  $scope.svgHeight = 400;
    
  $scope.originalData = [];
  $scope.plotData = [];

  $scope.keyOffset = 10;
  
  $scope.plotTypes = IllP.plotTypesCycle;
  $scope.plotType = $scope.plotTypes[1];

  $scope.surfaceTypes = IllP.surfaceTypes;
  $scope.laneTypes = IllP.laneTypes;
  $scope.swathTypes = IllP.swathTypes;
  $scope.infile = "data/cycleMetrics.json";
  $scope.maxColumn = 0;

 //selectors 0 means all
  $scope.selectSwath = "all";
  $scope.selectSurface = "both";
  $scope.selectLane = "all";
  $scope.selectRead = 0; //this option will change start cycle and max cycle! maybe not necessary. not implemented
  $scope.selectCycle = 1;

  $scope.cycleMin = 100000;
  $scope.cycleMax = 0;
  $scope.allMax = 0; 
  $scope.allMin = 100000; 
  $scope.rectWidth = 6;
  $scope.rectHeight = 4;

  iData.cycleData.async().then(function(cycleData){
      $scope.originalData = cycleData.data;
      $scope.maxTileNr = cycleData.maxTileNr;
      $scope.maxCycle = cycleData.maxCycle;
      $scope.laneTypes = cycleData.laneTypes;
      $scope.swathTypes = cycleData.swathTypes;
      $scope.maxLane = cycleData.maxLane;
      $scope.prepareData();
  });


  extractData = function(originalData, rowIndex, dataColumns, dataColumnKeys){
     var result = new Array(dataColumns.length);
     var tilePos = originalData.tileNr[rowIndex];
     var column = originalData.column[rowIndex];
     var lane = originalData.lane[rowIndex];

     for(var columnIndex = 0; columnIndex < result.length; columnIndex++){
        var originalDataColumn = dataColumnKeys[dataColumns[columnIndex]];
        var value = originalData[originalDataColumn][rowIndex];
        result[columnIndex] = {
           "column" : column,
           "lane" : lane,
           "tilePos" : tilePos,
           "channelNr" : columnIndex,
           "value" : value,
           "key" : column+"t"+tilePos+"i"+columnIndex
        };
     }
     return result;
  };

  allRange = function(originalData, dataColumns, dataColumnKeys){
     var len = dataColumns.length;
     var maxis = [];
     var minis = [];
     for(var columnIndex = 0; columnIndex < len; columnIndex++){
         var originalDataColumn = dataColumnKeys[dataColumns[columnIndex]];
         var originalDataV = originalData[originalDataColumn];
         var max = d3.max(originalDataV);
         var min = d3.min(originalDataV);
         maxis.push(max);
         minis.push(min);
     }
     var maxmin = { allMax : d3.max(maxis), allMin : d3.min(minis) };
     return maxmin;
  };


  $scope.prepareData = function(){
     var originalData = $scope.originalData;
     var maxRow = originalData.lane.length;
     var result = []; // _.map(_.range(0, $scope.plotType.dataColumns.length) , function(r){ return []; });
     var dataColumnKeys = _.keys(originalData);
     
     $scope.allMax = 0;
     for(var rowIndex = 0; rowIndex < maxRow; rowIndex++){
         var selected = IllP.isSelected(originalData, rowIndex, $scope.selectLane, $scope.selectSurface, $scope.selectSwath, $scope.selectCycle);
         if(selected){
             var extractedData = extractData(originalData, rowIndex, $scope.plotType.dataColumns, dataColumnKeys);
             for(var ei = 0; ei < extractedData.length; ei++){
                result.push(extractedData[ei]);
             }
         }
     }
    // var fv = function(result, f){ return f(_.map(result, function(res){ return f(res, function(r){ return r.value; }); }) );};
     var max = d3.max(result, function(r){ return r.value; });
     var min = d3.min(result, function(r){ return r.value; });
     var maxMin =  allRange(originalData, $scope.plotType.dataColumns, dataColumnKeys);
     $scope.allMax = maxMin.allMax;
     $scope.allMin = maxMin.allMin;
     $scope.plotData = result;
     $scope.cycleMax = max;
     $scope.cycleMin = min;
     $scope.plotData = result;
     $scope.maxColumn = d3.max(result, function(r){ return r.column; });
  };

  $scope.plotRenderer = function(el, data) {
    var plotId = "cycleHeatmap";

    var marginLeft = 20;
    var marginTop = 18;

    var width = $scope.svgWidth;
    var height = $scope.svgHeight;

    if(data.length == 0){
      console.log("data length 0");
      return;
    }
    
    var dataRange = [$scope.allMin,$scope.allMax];
    var dataRangePoints = _.range($scope.allMin, $scope.allMax, ($scope.allMax - $scope.allMin)/40).reverse();

    var color = d3.scale.linear().domain(dataRange).range(['green', 'yellow']);
    el.selectAll("#"+plotId)
        .data([0])
        .enter()
        .append("g")
        .attr("transform", "translate("+marginLeft+","+marginTop+")")
        .attr("id", plotId);
         
    var plot = d3.selectAll("#"+plotId);    
     

    plot.selectAll('.heatrect')
        .data($scope.plotData, function(d,i){
           return d.key; 
        }).enter()
        .append('rect')
        .attr("class", "heatrect")
        .attr('x', function(d){ 
            return d.column * $scope.rectWidth + d.lane * $scope.rectWidth; 
        })
       .attr('y', function(d, i){ 
            return d.tilePos * $scope.rectHeight + d.channelNr * $scope.maxTileNr * $scope.rectHeight + $scope.keyOffset * d.channelNr; 
        })
        .attr('width',  $scope.rectWidth)
        .attr('height', $scope.rectHeight)
        .attr('stroke' , 'none')
        .transition()
        .duration(500)
        .attr("fill-opacity", 1)
        .style('fill', function(d, i) { 
           return color(d.value); 
        });
     

 
     plot.selectAll('.heatrect')
         .data($scope.plotData, function(d,i){
            return d.key;
         })
         .style("fill", function(d,i){
             return color(d.value);
         });

     plot.selectAll('.heatrect')
        .data($scope.plotData, function(d,i){
            return d.key;
         })
        .exit()
        .transition()
        .duration(500).attr("fill-opacity", 0)
        .remove();
    
     var legend = IllP.createLabels($scope.plotType.columnLabels, $scope.plotType.colours);
     for(var legendIndex = 0; legendIndex < legend.length; legendIndex++){
         var yp = function(li){ return li * $scope.maxTileNr * $scope.rectHeight + $scope.keyOffset * li };
         var top = yp(legendIndex);
         var bot = yp(legendIndex + 1);
        legend[legendIndex].ypos = -(top+bot)/2;  
     }

     plot.selectAll('#leftLab')
         .data(legend, function(d,i){ 
             return d.key; 
         })
         .style("fill", function(d, i){ return d.colour })
         .transition().duration(500)
         .attr("x", function(d, i){ return d.ypos; })
         .attr("fill-opacity", 0.5);
           
     plot.selectAll('#leftLab')
         .data(legend, function(d,i){ 
             return d.key; 
          })
         .enter()
         .append('text')
         .attr("id", "leftLab")
         .attr('x', function(d,i){ return d.ypos; })
         .attr('y', 0 )
         .attr('text-anchor', "middle")
         .attr('transform', "rotate(-90)")
         .attr("fill" , function(d, i){ return d.colour; })
         .attr("fill-opacity", function(d, i){ return 0.5; })
         .text(function(d,i){ return d.key; }) 
    ;
         
     plot.selectAll('#leftLab')
         .data(legend, function(d,i){ 
             return d.key; 
         })
         .exit()
         .transition()
         .duration(500).attr("fill-opacity", 0)
         .remove()
      ;

     var right = $scope.maxColumn * $scope.rectWidth + $scope.maxLane * $scope.rectWidth + 60;
     var topB = 40;

      plot.selectAll('.colorbar')
        .data(dataRangePoints, function(d,i){
            return i;
        })
        .style('fill', function(d, i){
              return color(d);
        })
        ;


      plot.selectAll('.colorbar')
          .data(dataRangePoints, function(d, i){
              return i;
           })
          .enter()
          .append('rect')
          .attr('class', "colorbar")
          .attr('x', right)
          .attr('y', function(d,i){ return i * $scope.rectHeight + topB; })
          .attr('width',  $scope.rectWidth * 3 )
          .attr('height', $scope.rectHeight )
          .style('fill', function(d,i){ 
              return color(d); }) 
          ;

      plot.selectAll('.colorbar')
          .data(dataRangePoints, function(d,i){
             return i;
          })
        .style('fill', function(d, i){
              return color(d);
         })
         ;


      plot.selectAll('.colorbar')
          .data(dataRangePoints, function(d, i){
             return i;
         })
         .exit()
         .transition()
         .duration(500).attr('fill-opacity', function(d, i){ return 1; })
         .remove()
         ;

      plot.selectAll('.colorbarR')
          .data([0])
          .enter()
          .append('rect')
          .attr('class', 'colorbarR')
          .attr('x', right)
          .attr('y', topB )
          .attr('width', $scope.rectWidth * 3 )
          .attr('height', $scope.rectHeight * dataRangePoints.length)
          .style('fill', "none")
          .style('stroke', 'black')
          ;


     var y = d3.scale.linear().domain(dataRange).range([$scope.rectHeight * dataRangePoints.length, 0]);          
      var yAxis = d3.svg.axis()
                .scale(y)
                .ticks(5)
                .orient("right");

      var yaxs = plot
               .selectAll(".yaxis")
               .data([dataRange]);

        yaxs.enter().append("g")
             .attr("class", "yaxis")
             .attr("transform", "translate("+(right + $scope.rectWidth * 3)+"," + topB + ")");
       
         yaxs.transition()
             .duration(500)
             .call(yAxis); 
  
  };

} 

