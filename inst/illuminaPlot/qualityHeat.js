

function QualityHeatCtrl($scope, iData) {
  $scope.svgWidth = 512;
  $scope.svgHeight = 400;

  $scope.originalData = [];
  $scope.plotData = [];
  $scope.tileCounts = [];

  $scope.keyOffset = 10;

  $scope.surfaceTypes = IllP.surfaceTypes;
  $scope.laneTypes = IllP.laneTypes;
  $scope.swathTypes = IllP.swathTypes;
  $scope.infile = "data/cycleMetrics.json";
  $scope.maxColumn = 0;

  $scope.selectSwath = "all";
  $scope.selectSurface = "both";
  $scope.selectLane = "all";
  $scope.selectRead = 0; //this option will change start cycle and max cycle! maybe not necessary. not implemented
//$scope.selectTiles = ???

  $scope.allMax = 0;
  $scope.rectWidth = 6;
  $scope.rectHeight = 4;
  $scope.maxQuality = 45;

  var createBins = function(maxCycle, maxQuality){
        return _.map(_.range(1,maxCycle+1), function(cycle){
             var arr = new Array(maxQuality);
             for(i = 0; i < maxQuality; i++){
                 arr[i] = 0;
             }
             return { cycle: cycle, values: arr };
        });
  };

  //one could use the data from the other json 
  //one could precalculate this
  var createTileCounts = function(originalData){
      var allCounts = [];
      var maxRow = originalData.lane.length;
      for(var rowIndex = 0; rowIndex < maxRow; rowIndex++){      
          var count = originalData.basecallsNrA[rowIndex] + originalData.basecallsNrC[rowIndex] + originalData.basecallsNrG[rowIndex] + originalData.basecallsNrT[rowIndex] + originalData.basecallsNrNo[rowIndex];    
          allCounts.push(count);
      }
      return allCounts;
  };

  iData.cycleData.async().then(function(cycleData){
      $scope.originalData = cycleData.data;
      $scope.maxTileNr = cycleData.maxTileNr;
      $scope.maxCycle = cycleData.maxCycle;
      $scope.laneTypes = cycleData.laneTypes;
      $scope.swathTypes = cycleData.swathTypes;
      $scope.maxLane = cycleData.maxLane;
      $scope.tileCounts = createTileCounts(cycleData.data);
      $scope.prepareData();
  });


  $scope.prepareData = function(){
     var originalData = $scope.originalData;
    
     var resultArray = createBins($scope.maxCycle, $scope.maxQuality); 
     var maxRow = originalData.lane.length;
     for(var rowIndex = 0; rowIndex < maxRow; rowIndex++){
         var selected = IllP.isSelected(originalData, rowIndex, $scope.selectLane, $scope.selectSurface, $scope.selectSwath, "all");
         if(selected){
            var qual = originalData.medianQ[rowIndex];
            var cycle = originalData.cycle[rowIndex]; 
            var counts = $scope.tileCounts[rowIndex];
            resultArray[cycle - 1].values[qual] += counts;
         } 
     }
     var max = d3.max(_.map(resultArray, function(r){ return _.max(r.values);  }));
     var result = _.flatten( _.map(resultArray, function(r){ 
            var ta = [];
            for(q = 0; q < $scope.maxQuality; q++){
               var t = { cycle: r.cycle, quality: q, count: r.values[q], key: r.cycle+":"+q };
               ta.push(t);    
            }
            return ta;
     }));  
     $scope.allMax = max;
     $scope.plotData = result;
  };  
  
   

  $scope.plotRenderer = function(el, data) {
    var marginLeft = 60;
    var marginTop = 25;
    var marginBottom = 25;
    var width = $scope.svgWidth;
    var height = $scope.svgHeight;
    var plotId = 'qualityHeat';

    var rectWidth = (width - marginLeft)/$scope.maxCycle;
    var rectHeight = (height - (marginBottom+marginTop))/$scope.maxQuality;    

    var plotData = data;

    if(plotData.length == 0){
      return;
    }

   var xRange = [1, $scope.maxCycle];
   var yRange = [$scope.maxQuality, 0];
   var dataRange = [0,$scope.allMax];
   var color = d3.scale.linear().domain(dataRange).range(['green', 'yellow']);
   var x = d3.scale.linear().domain(xRange).range([0,width - marginLeft]);
   var yH = height - ( marginTop + marginBottom);
   var y = d3.scale.linear().domain(yRange).range([0, yH]);

   
   el.selectAll("#"+plotId)
        .data([0])
        .enter()
        .append("g")
        .attr("transform", "translate("+marginLeft+","+marginTop+")")
        .attr("id", plotId);

    var plot = d3.selectAll("#"+plotId);


    plot.selectAll('.qheatrect')
        .data($scope.plotData, function(d,i){
           return d.key;
        }).enter()
        .append('rect')
        .attr("class", "qheatrect")
        .attr('x', function(d){
            return x(d.cycle);
        })
       .attr('y', function(d, i){
            return y(d.quality);
        })
        .attr('width',  $scope.rectWidth)
        .attr('height', $scope.rectHeight)
        .attr('stroke' , 'none')
        .transition()
        .duration(500)
        .attr("fill-opacity", 1)
        .style('fill', function(d, i) {
		   return d.count == 0 ? "white" : color(d.count);
        });



     plot.selectAll('.qheatrect')
         .data($scope.plotData, function(d,i){
            return d.key;
         })
         .style("fill", function(d,i){
             return d.count == 0 ? "white" : color(d.count);
         });

     plot.selectAll('.qheatrect')
        .data($scope.plotData, function(d,i){
            return d.key;
         })
        .exit()
        .transition()
        .duration(500).attr("fill-opacity", 0)
        .remove();
 
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

  };

};








