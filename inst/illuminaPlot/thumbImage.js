function ThumbImageCtrl($scope, iRun) {
		
    $scope.channels = ["A","C","G","T"];
	$scope.surfaces = ["top","bottom"];
	$scope.maxCycle = 1;
	$scope.lanes = [1];
	$scope.tiles = [1];
	$scope.swaths = [1];
	
    iRun.statusInfo.async().then(function(statusInfo){
		$scope.maxCycle = statusInfo.RTA.correctedCycle;
		$scope.newImagePath();
    });
	
	iRun.runInfo.async().then(function(runInfo){	
		$scope.lanes = _.range(1, runInfo.layout.LaneCount + 1);
		$scope.tiles = _.range(1, runInfo.layout.TileCount + 1);
		$scope.swaths = _.range(1, runInfo.layout.SwathCount + 1);
	});
    		
    $scope.selectCycle = 1;
	$scope.selectLane = 1;
	$scope.selectSurface = "top";
	$scope.selectSwath = 1;
	$scope.selectTile = 1;
	$scope.selectChannel = "A";
 
        
    /**
	*  generates the path to a tile
	*
	*/
	$scope.generateTilePath = function(){
  	    var prefix = "Thumbnail_Images";
		var lane = "L00"+$scope.selectLane;
		var cycle = "C"+$scope.selectCycle+".1"; //Don't know why .1
	    var lanePrefix = "s_"+$scope.selectLane+"_";
		var surface = $scope.selectSurface == "top" ? 1 : 2;
		var tile = ($scope.selectTile < 10 ? "0" : "") + $scope.selectTile;
		var tileName = ""+surface+$scope.selectSwath+tile;
		var jpg = lanePrefix+tileName+"_"+$scope.selectChannel+".jpg";  
	    var path = prefix+"/"+lane+"/"+cycle+"/"+jpg;  
	    return path;
    };

    $scope.newImagePath = function(){
        $scope.imagePath = $scope.generateTilePath();
    };

    $scope.imagePath = $scope.newImagePath();

};