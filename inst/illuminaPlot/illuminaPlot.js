var illuminaData = angular.module('illuminaData',[]);

illuminaData.factory('iData', function($http){
    
    var cycleUrl = "data/cycleMetrics.json";
    var cycleData = {  
      async: function(){
            var promise = $http({method: 'GET', url: cycleUrl}).then(function(response){
                console.log("made call to: "+cycleUrl);  
                var td = {};
                var data = response.data;
                td.data = data;
                td.maxTileNr = _.max(data.tileNr);
                td.maxCycle = _.max(data.cycle);
                td.allLanes = _.uniq(data.lane).sort();
                td.maxLane = _.max(td.allLanes);
                td.allSwaths = _.uniq(data.swath).sort();
                td.laneTypes = ["all"].concat(td.allLanes);
                td.swathTypes = ["all"].concat(td.allSwaths);
                return td;
            });
            return promise;
        }
   };

   var tileUrl = "data/tileMetrics.json" 
   var tileData = {
       async: function(){
              var promise = $http({method: 'GET', url: tileUrl}).then(function(response){
                  console.log("made call to: "+tileUrl);
                  var td = {};
                  var data = response.data;
                  td.data = data;
                  td.allLanes = _.uniq(data.lane).sort();
                  td.allSwaths = _.uniq(data.swath).sort();
                  td.maxLane = _.max(td.allLanes);
                  td.laneTypes = ["all"].concat(td.allLanes);
                  td.swathTypes = ["all"].concat(td.allSwaths);
                  return td;
              }); 
             return promise; 
       }
   };
   return { cycleData: cycleData, tileData: tileData };

});

illuminaData.factory('iRun', function($http){
    
    var runUrl = "data/runInfo.json";
    var runInfo = {
      async: function(){
            var promise = $http({method: 'GET', url: runUrl}).then(function(response){
                console.log("made call to: "+runUrl);  
                return response.data;
            });
            return promise;
	}};
	var statusUrl = "data/status.json";
	var statusInfo = {  
      async: function(){
            var promise = $http({method: 'GET', url: statusUrl}).then(function(response){
                console.log("made call to: "+statusUrl);  
                return response.data;
            });
            return promise;
	}};
	return { runInfo: runInfo, statusInfo: statusInfo };
});


var illuminaPlot = angular.module('illuminaPlot',['illuminaData','ngCookies','ui.router','d3','ui.bootstrap','ui.bootstrap-slider']); 

illuminaPlot.config(function($stateProvider, $urlRouterProvider){
  //
  // For any unmatched url, send to /route1
  $urlRouterProvider.otherwise("/route1") 
  //
  // Now set up the states
  $stateProvider
    .state("index", {
        url: "",
        views: {
            cyclePlot : {
              templateUrl: "cyclePlot.html",
              controller: CyclePlotCtrl
            },
            lanePlot : {
              templateUrl: "lanePlot.html",
              controller: LanePlotCtrl
            },
            cycleHeat : {
              templateUrl: "cycleHeat.html",
              controller: CycleHeatCtrl
            },
		    thumbImage : {
              templateUrl: "thumbImage.html",
	          controller: ThumbImageCtrl
		    }
        }
    })
});


var IllP = {
    plotTypesCycle :  [
      { "label": "fwhm",                 "dataColumns" : [3,4,5,6],               "columnLabels": ["A", "C", "G","T"], "colours": ["green", "blue", "black", "red"]},
      { "label": "Raw Intensity",        "dataColumns" : [7,8,9,10],              "columnLabels": ["A", "C", "G","T"], "colours": ["green", "blue", "black", "red"]},
      { "label": "Corrected Intensity",  "dataColumns" : [12,13,14,15,16],        "columnLabels" : ["Average","A","C","G","T"], "colours": ["grey", "green", "blue", "black", "red"] },
      { "label": "Called Intensity",     "dataColumns" : [17,18,19,20],           "columnLabels" : ["A","C","G","T"], "colours" : ["green", "blue", "black", "red"] },
      { "label": "Basecalls" ,           "dataColumns" : [21,22,23,24,25],        "columnLabels" : ["N", "A","C","G","T"], "colours": ["grey", "green", "blue", "black", "red"] },
      { "label": "SNR" ,                 "dataColumns" : [26],                    "columnLabels" : ["SNR"], "colours": ["blue"]},
      { "label": "% > Q30",              "dataColumns" : [27],                    "columnLabels" : ["% > Q30"], "colours": ["blue"]},
      { "label": "median Q",             "dataColumns" : [28],                    "columnLabels" : ["median Q"], "colours": ["blue"], "statFun" : d3.median },
      { "label": "error rate",           "dataColumns" : [29],                    "columnLabels" : ["error rate"], "colours": ["blue"]},
      { "label": "errors",               "dataColumns" : [30,31,32,33,34],        "columnLabels" : ["0","1","2","3","4"], "colours": ["#EFF3FF","#BDD7E7", "#6BAED6", "#3182BD", "#08519C"], "chartType": "area" }
     ],
     //TODO:  allow heat map of single columns in addition
     plotTypesLane : [ 
      { "label": "Cluster Density, violin",            "dataColumns" : [8,9],     "columnLabels" : ["all clusters", "pf clusters"], "colours": ["red","blue"], "chartType": "violin", "ylab": "Cluster Density (k/mm2)" },
      { "label": "Number of clusers",                  "dataColumns" : [10,11],   "columnLabels" : ["all clusters", "pf clusters"], "colours": ["red","blue"], "chartType": "bar", "ylab": "Cluster Count sum" }
     ],         
     
     surfaceTypes : ["both", "top", "bottom"],
     
     laneTypes : ["all"],
     
     swathTypes : ["all"],
     
     isSelected : function(originalData, rowIndex, selectLane, selectSurface, selectSwath, selectCycle){
         var laneSelected = selectLane != "all" ? selectLane == originalData.lane[rowIndex] : true;
         if(laneSelected){
            var surfaceSelected = selectSurface != "both" ? selectSurface == originalData.surface[rowIndex] : true;
            if(surfaceSelected){
                var swathSelected = selectSwath != "all" ? selectSwath == originalData.swath[rowIndex] : true;
                if(swathSelected){
                    var cycleSelected = selectCycle != "all" ? selectCycle == originalData.cycle[rowIndex] : true;
                    return cycleSelected;
                }else{
                    return false;
                }
            }else{
                return false;
            }
         }else{
             return false;
         }
     },

     createLabels: function(columnLabels, colours, opacity){
        var labels = [];
        for(var i = 0; i < columnLabels.length; i++){
           var l = { key: columnLabels[i], colour: colours[i], opacity: opacity !== undefined ? opacity[i] : 1 };
           labels.push(l);
        }
        return labels;
     },

     plotLegend : function(plot, labels, id, plotWidth){ //labels is array of { key: name, colour: colour, opacity: opacity }
                        _.each(labels, function(element, index, list){ element.ind = index; });    
                        var bowx = 10;
                        var spaceBox = 2;
                        var pad = 5;
                        var cumulative = 0;
                        
                        var legend = plot.selectAll("#legend"+id).data([0]);
                            legend.enter().append("g")
                            .attr("id", "legend"+id)  
                            ;
                       
                        var labs = legend.selectAll("text").data(labels, function(d,i){ return d.key; });
                            labs.enter()
                            .append("text")
                            .attr("x", 0 )
                            .attr("y", 0)
                            .attr("stroke-opacity", function(d, i){ return d.colour; })
                            .attr("fill" , function(d, i){ return d.colour; })
                            .attr("fill-opacity", function(d, i){ return d.opacity; })
                            .attr("class", "colorLegend")
                            .text(function(d, i){ 
                                return d.key; 
                            }); 

                            labs.exit().remove();

                          // labs.transition().duration(500)
                               

                           var tlH = _.map(labs[0], function(p){ return p.getBBox().height; })[0];
                           var tlW = _.map(labs[0], function(p){ return p.getBBox().width + pad; });
                           var tlWt = [0].concat(tlW.slice(0, tlW.length - 1));
                           var tlWcum = _.reduce(tlWt, function(acc, n){ acc.push( (acc.length > 0 ? acc[acc.length-1] : 0) + n); return acc }, []);

                           var totalW = d3.sum(tlW) + 4; //for rect line
                           labs.attr("transform", function(d, i){
                                 return "translate("+(plotWidth-totalW + tlWcum[d.ind])+",-"+tlH/3+")";
                            });
                           
                     
                           
                         

                      var rec = legend.selectAll("rect").data([labels], function(d,i){ 
                          var key = _.map(d, function(v){ return v.key; }).join("");
                          return key;
                      });
                       rec.enter()
                            .append("rect")
                            .attr("x", plotWidth - totalW - pad)
                            .attr("y", -tlH * 1.3)
                            .attr("height", tlH * 1.3)
                            .transition().duration(500)
                            .attr("width", totalW + pad)
                            .attr("stroke", "#333333")
                            .attr("fill-opacity", 0 ); 
                       
                       rec.exit().transition().duration(500).attr("width", totalW + pad).remove();
     }

};
