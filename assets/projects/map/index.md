---
layout: single
---


<div id="document" style="width:900px;font-family:Arial,Verdana,sans-serif;">
	<div style="margin-left:15px;margin-top:15px;margin-right:15px">
	<h3 class="post">Dynamic Graph Map</h3>
	<br />	<p>This summer as part of my internship I was tasked with finding a map-based way to compare and display data across regions, institutions, services offered at those institutions and when those services were offered. The below uses real institutions but FAKE DATA. Works best in Google Chrome.
	</div>
	<div id = "controls">
		<nav class="segmented">
		<input type="radio" onclick="HRRToggle()" id="HRRtog" name="regionTog" checked>
		<label for="HRRtog">Hospital Ref. Regions</label>
		<input type="radio" onclick="StateToggle()" id="stateTog" name="regionTog">
		<label for="stateTog">States</label>
	<!--	<button id=HRRbutton   onclick="HRRToggle()">Toggle Healthcare Regions</button>-->
<!--	<button id=Statebutton onclick="StateToggle()">Toggle State Colors</button>-->
		<input type="button" id="Pointbutton" onclick="PointToggle()">
		<label for="Pointbutton" style="margin-left:15px">Show Hospitals</label>
		</nav>
	</div>
		<div id="map"></div>  <!-- I followed an example that put the map in a <p>, rather than a <div>. The actual tag used for the map id is probably arbitrary -->
		<div id="rightControl">
			<h3 class="pagetext" style="margin-bottom:0px">Care Period</h3>
			<input type="checkbox" class="status" onclick="statusBoxControl(this,'overall');">Overall</input><br/>
			<input type="checkbox" class="status" onclick="statusBoxControl(this, 'pre');" checked>Pre-Episode</input><br/>
			<input type="checkbox" class="status" onclick="statusBoxControl(this, 'post');" >Post-Episode</input><br/>
			<input type="checkbox" class="status" onclick="statusBoxControl(this, 'during');" >During Episode</input><br/>
			
			<h3 class="pagetext" style="margin-bottom:0px">Illness</h3>

			<input type="checkbox" class="drg" onclick="DRGBoxControl(this,'all');" >All</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this,  61);" >Illness 61</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this,  62);" >Illness 62</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this, 190);" >Illness 190</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this, 191);" >Illness 191</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this, 192);" >Illness 192</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this, 280);" checked>Illness 280</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this, 281);" >Illness 281</input><br/>
			<input type="checkbox" class="drg" onclick="DRGBoxControl(this, 282);" >Illness 282</input><br/>
		</div>
		<div id="drgControl"></div>
		<div class = "indicator"></div>
		<div id="belowMapContainer">
			<div id="barChart" style="text-align:center">
				<h3 class="pagetext" style="text-align: center;margin-top:0px;margin-bottom:0px">National Distribution</h3>
			<div class = "chartProvider"></div>
			<div><p class = "chartLocation" /></div>
			<b><font color="steelblue">National Avg</font> &mdash; <font color="brown">Regional Avg</font> &mdash; <font color="red">Facility</font></b>
		</div>
		<div class="regionInfo" id="regionBox">
			<div id="regionName"></div>
			<hr style="display:none">
			<table id="regionOverall"><tbody id="regionOverallTbody">
				
			</tbody></table>
		</div>
	</div>
</div>

<div class ="tooltip">
	<div class = "provider"></div>
	<div><p class = "location" /></div>
	<hr>
	<table class = "dataContainer"><tbody>
	</tbody></table>
</div>
<script type="text/javascript"> 
	//Define a bunch of things here in the 'global' scope so you can access them outside 
	// of where they're defined.

	//status/indicator variables
	var currentStatus = "pre";
	var currentDRG = "280";
	
	var stateColorStatus = 0;
	var HRRstatus = 0; 
	var pointStatus = 0;

	var stateColor;  //global save for when mousing over and darkening

	//Leaflet map parameters	
	var svg; //The svg canvas in the Leaflet overlay layer. Everything not in the histogram
		 // or the table happens here

	//Initialize to Lebanon, KS at zoom level 4 
//	var map = new L.Map("map")
	var map = L.TileJSON.createMap('map', osmTileJSON)
		.setView(new L.LatLng(37.8, -96.9), 4)

		// the long string is the cloudmade developer key for acumenPatrick. You'll probably want a different one.
		// the rest of the string is described here: http://developers.cloudmade.com/projects/tiles/documents
		.addLayer(new L.TileLayer("http://{s}.tile.cloudmade.com/a235c8598e974e2d9e6d8279d3c5e978/998/256/{z}/{x}/{y}.png"))

	var svg = d3.select(map.getPanes().overlayPane).append("svg")
		.on("mousemove", function() { MousePosition = d3.svg.mouse(this) });

	//Entity definitions
	var stateAreas;
	var HRRareas,
	    hrrG;
	var providerDots;
	var providerData;

	//csv data 
	var hrrValues;   //global access variable for HRR CSV data
	var stateValues; //global access variable for state CSV data
	var provValues;  //global access variable for provider CSV data
	var natValues;

	//set up color scales for fill
	var themeselection = "YlGn",  // ColorBrewer color theme selection here
	    colorScale = d3.scale.quantile();  // defines quantile color scale

	//implements the color legend as a Leaflet control. This makes it much easier to overlay on the map
	// in a predictable way and inherit a little CSS from the 'leaflet-control' class. It also inherits its own 
	// CSS. The actual work of drawing its elements and coloring them in is still done with d3.

	var colorLegend = L.Control.extend({
		options: {
			position: 'topright'},
		onAdd: function(map) {
			var legendContainer = L.DomUtil.create('div', 'colorLegend');
			return legendContainer;}
	});

	map.addControl(new colorLegend());

	//Legend definitions
	legendWidth           = 180;
	legendInsideMargin    = 8;
	legendLeftMargin      = 10;
	legendTitleHeight     = 20;

	numStateLegendBuckets = 7;
	numHRRLegendBuckets   = 4;
	numLegendMax          = 9;

	var legendRects;
	var legendText;
	legendRectHeight      = 30;
	legendRectWidth       = 30;

	d3.select(".colorLegend")
		.append("div")
		.attr("id","legendTitle")
		.append("span")
		.attr("id","legendTitleText")
		.text("Legend title here") //gets overwritten by d3 in refreshLegend()
		.style("display","none")

	var legend    = d3.select(".colorLegend")
	var legendSVG = legend.append("svg")
	var legendG   = legendSVG.append("g")
		.attr("id","legendG")

	//Histogram definitions
	var histogram         = [];
	var betweenBarMargin  = 4;
	var barWidth          = 400;
	var barHeight         = 300;
	var histAxisScale; //will be d3.scale.linear to transform money value into x-axis pixel placement
	var nationalMean;

	//svg subcontainers
	var stateG = svg.append("g")
		.attr("id", "states");

	var hrrG   = svg.append("g")
		.attr("id", "HRRs");

	var providerG = svg.append("g")
		.attr("id", "providers")

	var barChartContainer = d3.select("#barChart").append("svg")
		.attr("width", barWidth)
		.attr("height", barHeight+60)
	    .append("g")
		.attr("id","barChartSVG")

	//general use formatting functions
	var moneyFmt = d3.format(",r") //wrap around d3.round(,2)
	var percentFmt = d3.format(",.2%")

	//Copying vertices to provderData allows access everywhere - makes life easier
	d3.csv("data/provider-geodata.csv", function(vertices){
		providerData = vertices;})

	//introduction of US data CSV
	d3.csv("data/state-filetypes-and-overall.csv", function(stateVars){

		//d3.csv will read everything as a string - you need to manually coerce numbers
		// to actually BE numbers

		stateVars.forEach(function(d) {
			d.epcost = parseFloat(d.epcost);
		});	

		//status is last so we can iterate over them and build an overall
		statesByDRGByStateByStatusByType = d3.nest()
				.key(function(d){return d.drg})
				.key(function(d){return d.state})
				.key(function(d){return d.status})
				.key(function(d){return d.type})
				.rollup(function(d){return formatData(d)})
				.map(stateVars);

		//create an 'overall' status by summing pre, post and during
		buildOverallStatus(statesByDRGByStateByStatusByType);

		//write to globally defined variable	
		stateValues = stateVars;
	}) //end d3.csv states

	d3.csv("data/hrr-filetypes-and-overall.csv", function(hrrVars){

		hrrVars.forEach(function(d) {
			d.epcost = parseFloat(d.epcost);
		});	

		//status is last so we can iterate over them and build an overall
		HRRsByDRGByHRRByStatusByType = d3.nest()
				.key(function(d){return d.drg})
				.key(function(d){return d.hrrnum})
				.key(function(d){return d.status})
				.key(function(d){return d.type})
				.rollup(function(d){return formatData(d)})
				.map(hrrVars);

		//create an 'overall' status by summing pre, post and during
		buildOverallStatus(HRRsByDRGByHRRByStatusByType);

		//write to globally defined variable	
		hrrValues = hrrVars;

		HRRToggle();
(function()
	{
	$('#popup').trigger('click');
	})();
	}) //end d3.csv hrr

	d3.csv("data/provider-filetypes-and-overall.csv", function(provVars){
		provVars.forEach(function(d) {
			d.epcost = parseFloat(d.epcost);
		});

		provsByDRGByProvByStatusByType = d3.nest()
				.key(function(d){return d.drg})
				.key(function(d){return d.provider})
				.key(function(d){return d.status})
				.key(function(d){return d.type})
				.rollup(function(d){return formatData(d)})
				.map(provVars);

		//create an 'overall' status by summing pre, post and during
		buildOverallStatus(provsByDRGByProvByStatusByType);

		//write to globally defined variable	
		provValues = provVars;	
	}) //end d3.csv provider
	
	d3.csv("data/nation-filetypes-and-overall.csv", function(natVars){
		natVars.forEach(function(d){
			d.epcost = parseFloat(d.epcost);
		});	

		nationalByDRGByStatusByType = d3.nest()
			.key(function(d){return d.drg})
			.key(function(d){return d.status})
			.key(function(d){return d.type})
			.rollup(function(d){return formatData(d)})
			.map(natVars)

		natValues = natVars;
	}) //end d3.csv nation

	d3.csv("data/predictors.csv", function(predictorVars){
		predictorVars.forEach(function(d){
			d.DRG_CD = parseFloat(d.DRG_CD)
		});

		predictorsByDRGByProvider = d3.nest()
			.key(function(d){return d.DRG_CD})
			.key(function(d){return d.provider})
			.map(predictorVars)

		predValues = predictorVars;
	}) //end d3.csv predictors

	//load states and HRRs
	//functions are nested so that both collection and Hcollection can be accessed.
	// Note - these json files don't have variables declared inside of them like some do 
	d3.json("data/us-states_noPR_abbr.json", function(collection) {
	d3.json("data/HRRs.json", function(Hcollection) {

		//define a bounding box
		var bounds = d3.geo.bounds(collection);
		var path   = d3.geo.path().projection(project);

		//Define stateAreas, HRRareas and providerDots - each are elements of the master SVG.

		stateAreas = stateG.selectAll("path")
			.data(collection.features)
			.enter().append("path")
			.attr("class","state")
			.attr("id",function(d){return d.properties.name})
			.on("mouseover",function(d){
				if(pointStatus == 0){
					stateColor = (d3.select(this).style("fill"));
					d3.select(this).style("fill","brown")
				}
			})
			.on("mouseout", function(){
				if(pointStatus == 0){
					d3.select(this).style("fill",stateColor);
				}
			})

		HRRareas = hrrG.selectAll("path")	
			.data(Hcollection.features)
			.enter().append("path")
			.attr("id", function(d){ return d.properties.HRRNUM})
			.attr("class", "HRRclass")
			.attr("d", path)
			.style("display","none")

		//In JSON files with coordinate pairs the .data() method can just suck them up and go.
		// In cases like my CSV, where lat and lon are separate variables, I've found the best thing
		// is to create a Leaflet LatLng object and append it back to the datasource.

		providerData.forEach(function(d){
			d.LatLng = new L.LatLng(d.latitude, d.longitude)})

		providerDots = providerG.selectAll("circle")
			.data(providerData)
			.enter().append("svg:circle")
			.attr("id", function(d, i) { 
				return d.provider_id; })
			.style("display","none") //dots don't render on load
			.style("fill","#663412")
			.style("stroke","black")
			.style("stroke-width","1px")
		        .on("mouseover", function(d) {
				var provID = d.provider_id;
				
				if(provsByDRGByProvByStatusByType[currentDRG][provID] != undefined){

					var providerDataObject = provsByDRGByProvByStatusByType[currentDRG][provID][currentStatus]
					var stateDataObject    = statesByDRGByStateByStatusByType[currentDRG][d.state][currentStatus]
					var stateLocation      = histAxisScale(sumFileTypes(providerDataObject))
					var regionTotal        = sumFileTypes(stateDataObject)	

					d3.select("#regionName")
						.append("span")
						.attr("class","regionTitle")
						.text(d.provider_name+ ' (#' + provID + ')')

					total              = sumAcrossFileTypes(providerDataObject)['Total'];
					availableFileTypes = Object.keys(providerDataObject)

					d3.select("#regionBox").select("hr")
						.style("display","block")

					var trBody = d3.select("#regionOverallTbody").selectAll(".stateTr")
					trBody.data(availableFileTypes)
						.enter()
						.append("tr").attr("class","stateTr")
						.append("td").attr("class","stateTd")
						.text(function(d){
							return d.capitalize()});
							
					d3.selectAll(".stateTr")
						.append("td")
						.text(function(d){
							return '$'+moneyFmt(d3.round(providerDataObject[d].epcost,2))})
						.attr("class",function(d){
							if(currentStatus != "overall"){
								if(providerDataObject[d].epcost/nationalByDRGByStatusByType[currentDRG][currentStatus][d].epcost < 1){
									return "belowNational"}
								else{
									return "aboveNational"}
							}
						});

					d3.selectAll(".stateTr")
						.append("td")
						.attr("class","percent")
						.text(function(d){
							value = d3.round(providerDataObject[d].epcost/total,4);
							if(value <= 100) {						
								return '('+percentFmt(value)+')'}
							return '('+100+'%)' //prevents embarassment if a total is slightly >100%
					})

					d3.select("#regionOverallTbody").append("tr")
						.attr("class","totalTr")
						.append("td")
						.text("Total")

					d3.select(".totalTr")
						.append("td")
						.attr("class","totalValue")
						.text('$' + moneyFmt(d3.round(total,2)) )
				
					d3.select("#regionOverallTbody").append("tr")
						.append("td")
						.attr("colspan",3)
						.attr("id","compareToMean")
						.text(percentFmt(d3.round(total/regionTotal,4))+ " of State Mean ($" +moneyFmt(d3.round(regionTotal,2)) +")" )
						.attr("class",function(){
							if(total/regionTotal < 1){
								return "belowMean"}
							else if(total/regionTotal == 1){
								return "atMean"}
							return "aboveMean"})

					d3.select("#regionOverallTbody").append("tr")
						.append("td")
						.attr("colspan",3)
						.attr("id","compareToMean")
						.text(percentFmt(d3.round(total/nationalMean,4))+ " of US Mean ($" +moneyFmt(d3.round(nationalMean,2)) +")" )
						.attr("class",function(){
							if(total/nationalMean < 1){
								return "belowMean"}
							else if(total/nationalMean == 1){
								return "atMean"}
							return "aboveMean"})

					//histogram pointers
	
	
					//put the pointer on the edge of the frame if it wants to be far away
					if(stateLocation < 0){stateLocation = 0}
					if(stateLocation > barWidth){stateLocation = barWidth}	
				
					providerTriangle = d3.select("#barChartSVG").append("g")
						.attr("class","providerTriangle")
					
					//You have to draw the triangle from scratch: starting position, second, third
					// separated by l (lowercase L) if second and third are relative, L if absolute. 
					// Close shape with 'z'.

					providerTriangle.append("path")
						.attr('d', function(d){
							return 'M ' + stateLocation +' ' + 30 + ' l 15 -40 l -30 0 z'})
						.attr("class","providerTriangle")

					//your cursor is over a provider, not a state, so you need to draw the state's triangle too

					regionTriangle = d3.select("#barChartSVG").append("g")
						.attr("class","regionTriangle")
					
					regionTriangle.append("path")
						.attr('d', function(d){
							return 'M ' + histAxisScale(sumFileTypes(stateDataObject)) +' ' + 30 + ' l 15 -40 l -30 0 z'})
						.attr("class","regionTriangle")

					//we also need to take over filling in the state, and later putting it back
					stateHandle = '#'+d.state
					stateColor = d3.select(stateHandle).style("fill") //get existing color
					d3.select(stateHandle).style("fill","brown")
						

					//These values fill out the tooltip div				

					var providerBox = d3.select(".provider").text(d.provider_name);
					var locationBox = d3.select(".location").text(d.city + ", " + d.state);

					d3.select(".tooltip").style("display","block");

					//Make sure this is the coordinate system you want to use for the mouse
					//var xpos = d3.event.clientX;
					//var ypos = d3.event.clientY;
					var xpos = d3.event.pageX;
					var ypos = d3.event.pageY;

					d3.select(".tooltip")
						.style("left", xpos + "px")
						.style("top", ypos + "px");


					d3.select(this)
						.transition()
						.duration(200)
						.attr("r", 10)
					.style("fill","red")
				} //end if

					//this can be done in an elegant way, requiring more thought than I gave it
					if(predictorsByDRGByProvider[currentDRG] != undefined && predictorsByDRGByProvider[currentDRG][provID] != undefined){
						d3.select(".dataContainer").select("tbody").selectAll("tr").remove();				
	
						currentPredictors = predictorsByDRGByProvider[currentDRG][provID] 
						averagePredictor = predictorsByDRGByProvider[currentDRG]['avg'][0]
						
						dataCon = d3.select(".dataContainer").select("tbody")

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Number Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['n_claims'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['n_claims']-averagePredictor['n_claims'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['n_claims']<= averagePredictor['n_claims']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Inpatient Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['ip_type_sum'],2))	
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['ip_type_sum']-averagePredictor['ip_type_sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['ip_type_sum']<= averagePredictor['ip_type_sum']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Carrier(PB) Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['pb_type_sum'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['pb_type_sum']-averagePredictor['pb_type_sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['pb_type_sum']<= averagePredictor['pb_type_sum']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Skilled Nursing Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['sn_type_sum'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['sn_type_sum']-averagePredictor['sn_type_sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['sn_type_sum']<= averagePredictor['sn_type_sum']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Anesthesia (232) Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['proc232_Sum'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['proc232_Sum']-averagePredictor['proc232_Sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['proc232_Sum']<= averagePredictor['proc232_Sum']){return "belowMean"}else{return "aboveMean"}})


						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Tracheostomy (34) Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['proc34_Sum'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['proc34_Sum']-averagePredictor['proc34_Sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['proc34_Sum']<= averagePredictor['proc34_Sum']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Install-Adjust Pacemaker (48) Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['proc48_Sum'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['proc48_Sum']-averagePredictor['proc48_Sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['proc48_Sum']<= averagePredictor['proc48_Sum']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Avg Other Diagnostic (227) Claims")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['proc227_Sum'],2))
						dataConTr.append("td").text("("+d3.round(currentPredictors[0]['proc227_Sum']-averagePredictor['proc227_Sum'],2)+")")
							.attr("class",function(){
								if(currentPredictors[0]['proc227_Sum']<= averagePredictor['proc227_Sum']){return "belowMean"}else{return "aboveMean"}})

						dataConTr = dataCon.append("tr").attr("class","sampleSize")
						dataConTr.append("td").attr("class","tooltipLabel")
							.text("Sample size")
						dataConTr.append("td")
							.text(d3.round(currentPredictors[0]['_FREQ_'],2))

					}


			}) // end mouseover
			.on("mouseout",function(f) {
				d3.select(stateHandle).style("fill",stateColor)
				d3.select(".providerTriangle").remove();
				d3.select(".regionTriangle").remove()

				d3.select("#regionBox").select("hr")
					.style("display","none");
				d3.select("#regionBox").selectAll("tr").remove();
				d3.select(".regionTitle").remove();

				d3.select(".dataContainer").select("tbody").select("tr").remove();

				d3.select(this)
					.transition()
					.duration(200)
					.attr("r", Math.min(map.getZoom()-1, 6))
					.style("fill", "#663412");
				d3.select(".tooltip").style("display","none");
			}); 

		// The following 40 lines or so are Leaflet-centric functions. Don't alter them unless you know PRECISELY
		//  what you're doing and what you intend to achieve. 

		map.on("viewreset", reset);
		reset();

		// Reposition the SVG to cover the features.
		function reset() {
			var bottomLeft = project(bounds[0]),
			    topRight = project(bounds[1]);

			svg 
				.attr("width", topRight[0] - bottomLeft[0])
				.attr("height", bottomLeft[1] - topRight[1])
				.style("margin-left", bottomLeft[0] + "px")
				.style("margin-top", topRight[1] + "px");

			//The vector based items are defined by a 'path' value, so transforming them is pretty straightforward			
			stateG   .attr("transform", "translate(" + -bottomLeft[0] + "," + -topRight[1] + ")");
			hrrG     .attr("transform", "translate(" + -bottomLeft[0] + "," + -topRight[1] + ")");
			providerG.attr("transform", "translate(" + -bottomLeft[0] + "," + -topRight[1] + ")");

			stateAreas.attr("d", path);
			HRRareas  .attr("d", path);
			
			//There's a demo (http://bl.ocks.org/3047025) where circles are done as paths, but I find that confusing so I do them as svg:circles, 
			// (http://bl.ocks.org/3058935) which means you have to redefine the cx and cy values on each redraw.

			providerDots.attr("cx", function(d) { return map.latLngToLayerPoint(d.LatLng).x})
				.attr("cy", function(d) { return map.latLngToLayerPoint(d.LatLng).y})
				.attr("r", function(d) {
					radius = Math.min(map.getZoom()-1, 6)
					return radius;})

		/********  DON'T redefine on(mouseover) or on(mouseout) here - it will overwrite the original values. ***********/
		/********                     only worthwhile if scoping won't be an issue                            ***********/

		 } //end reset();
		
		//leaflet projection function - keeps objects at the right size and on the right part of the map	
		function project(x) {
			var point = map.latLngToLayerPoint(new L.LatLng(x[1], x[0]));
			return [point.x, point.y];
		}
	
	});//end d3.json("HRRs.json")
	});//end d3.json("us-states.json")	
	
	function refreshStates(){
		//Build and associative array of every extant state and its value across file types in the current situation
		// I enumerate keys in case a state is missing- saves me from having to sanitize nulls
		var availableStates = Object.keys(statesByDRGByStateByStatusByType[currentDRG]);
		var valuesStatesTake = {};
		var tempStateValue;
		
		for(var i = 0; i< availableStates.length; i++){
			tempStateValue = sumFileTypes(statesByDRGByStateByStatusByType[currentDRG][availableStates[i]][currentStatus]);
			
			valuesStatesTake[availableStates[i]] = tempStateValue;
		}

		var colorsStatesTake = defineColorScale(valuesStatesTake,availableStates,numStateLegendBuckets);
		colorsStatesTake["MD"] = "rgb(170,170,170)"; //MD is absent from P4P's data
		//updates each state's color accordingly
		stateAreas.transition()
			.duration(200)
			.style("fill-opacity", .6)
			.style("fill",function(d) { 
				return getRegionColor(d.properties.name,colorsStatesTake);

				//d.properties.name is the state name element (e.g. "Alabama")
				// in the shape file on which you're matching, therefore, it's 
				// important that the dataset can use the state name as a key
			});


		var roundNumberExtents = roundExtents(d3.extent(d3.values(valuesStatesTake)));		

		refreshLegend(valuesStatesTake,numStateLegendBuckets,roundNumberExtents);
		refreshHistogram(valuesStatesTake,roundNumberExtents);

	} //end refreshStates()

	function refreshHRRs(){

		//Build and associative array of every extant state and its value across file types in the current situation
		var availableHRRs = Object.keys(HRRsByDRGByHRRByStatusByType[currentDRG]);
		var valuesHRRsTake = {};
		var tempHRRValue;
		
		for(var i = 0; i< availableHRRs.length; i++){

			tempHRRValue = sumFileTypes(HRRsByDRGByHRRByStatusByType[currentDRG][availableHRRs[i]][currentStatus]);
			
			valuesHRRsTake[availableHRRs[i]] = tempHRRValue;
		}

		var colorsHRRsTake = defineColorScale(valuesHRRsTake,availableHRRs,numHRRLegendBuckets);
		
		//updates each state's color accordingly
		HRRareas.transition()
			.duration(200)
			.style("fill-opacity", .6)
			.style("fill",function(d) { 
				return getRegionColor(d.properties.HRRNUM,colorsHRRsTake);

				//HRRNUM is the HRR name element (e.g. 137)
				// in the shape file on which you're matching, therefore, it's 
				// important that the datset can use the name as a key
			});

		var roundNumberExtents = roundExtents(d3.extent(d3.values(valuesHRRsTake)));		

		refreshLegend(valuesHRRsTake,numHRRLegendBuckets,roundNumberExtents);
		refreshHistogram(valuesHRRsTake,roundNumberExtents);
	} //end refreshHRRs()

	function refreshHistogram(valuesRegionsTake,roundNumberExtents){
		var horizontalMargin = 30;
		var verticalMargin   = 20;
		var betweenBarMargin = 4;

		//first remove any lingering elements from the SVG
		d3.select("#barChartSVG").remove();	
		d3.select("#barChartSVG").selectAll("text").remove();	
	
		d3.select("#barChart").select("svg")
			.attr("width", barWidth)
			.attr("height", barHeight)
		    .append("g")
			.attr("id","barChartSVG")

		//then define the bars from which your chart will be made

		var histX = d3.scale.linear()
			.domain(roundNumberExtents)
			.range([horizontalMargin,barWidth-horizontalMargin])

		var numBins = histX.ticks(10) //a function that returns a number close to its 
					      //  argument depending on what would make the best
					      //  tick scale - e.g. 10 might look funny, it returns 9

		histogram = d3.layout.histogram()
			.bins(numBins)
			(d3.values(valuesRegionsTake))

		var histY = d3.scale.linear()
			.domain([0,d3.max(histogram, function(d) { return d.y})])
			.range([(barHeight), 0]);
		histY.nice() //Makes the domain nice round numbers.

		var xAxis = d3.svg.axis()
			.scale(histX)
			.orient("top")
			.ticks(histogram.length)
			.tickSize(5,-5)
		
		histAxisScale = xAxis.scale();

		nationalMean = d3.mean(d3.values(valuesRegionsTake))

		natlAvgTriangle = d3.select("#barChartSVG").append("g")
			.attr("class","natlAvgTriangle")

		natlAvgTriangle.append("path")
			.attr('d', function(d){
				return 'M ' + histAxisScale(nationalMean) +' ' + 30 + ' l 15 -40 l -30 0 z'})
			.attr("class","natlAvgTriangle")

		var bars = d3.select("#barChartSVG").selectAll(".bar")
			.data(histogram)	
			.enter().append("g")
			.attr("class","bar")
			.attr("transform", function(d) { 
				return "translate(" + histX(d.x) + ",0)";})
				//return "translate(" + histX(d.x) + "," + histY(d.y)+")";})

		//I subtract 2 here and add xTranslate below to enforce some minimum margin 
		// between bars, lest the algorithm close it
		rectangleWidth = (barWidth-2*horizontalMargin)/numBins.length-(betweenBarMargin);

		//to center the boxes in the axis bins, we first need to know the distance between tick marks
		tickMarkSpread = histX(histogram[1].x) - histX(histogram[0].x)
		//get the difference, divide by 2
		xTranslate = betweenBarMargin/2;

		//the translate line is crucial - SVGs have an origin in the top left, so without 
		// forcing each bar down the histogram would look upside down, bars emerging from
		// the ceiling.
		bars.append("rect")
			.attr("x", 1)
			.attr("width", rectangleWidth)
			.attr("height", function(d) {return .6*(barHeight - (histY(d.y))); })
			.attr("transform", function(d){
				return "translate("+xTranslate+","+(.17*barHeight + .6*(histY(d.y)))+")"});

		axis = d3.select("#barChartSVG").append("g")
			.attr("class", "axis")
			.attr("transform", "translate(0," + (.78*barHeight) + ")") 
			.attr("width",histogram.length*(rectangleWidth+betweenBarMargin))
			.call(xAxis)

		axis.selectAll("text")
			.attr("transform", "rotate(45) translate("+25+","+(.12*barHeight)+")")
			.text(function(d){return "$"+d})
	
		axis.selectAll("path")
			.attr("id","axisPath")
			.style("fill","none")
			.style("shape-rendering","crispEdges")
			.style("stroke","black")
	}

	function refreshLegend(values,numLegendBuckets,roundNumberExtents){
		var legendHeight = (numLegendBuckets+1)*(legendRectHeight+legendInsideMargin);

		legendSVG
			.attr("width", legendWidth)
			.attr("height", legendHeight);	

		//Set the legend title
		d3.select("#legendTitleText")
			.text(function(){
				return currentDRG.capitalize() + " - " + currentStatus.capitalize();})
			.style("display","block");

		d3.select(".colorLegend")
			.style("background","rgba(255,255,255,.8)")

		//prepare a colorBrewer scale with an extra 'null' value on the end for 'no data'

		//since the color scale will already have been defined by the function that called this
		// (either refreshStates or refreshHRRs) we don't have to define it- just read it to make
		// our scale

		var colorbrewerWithNull = [];
		for(var i = 0; i< numLegendBuckets; i++){
			colorbrewerWithNull[i] = colorbrewer[themeselection][numLegendBuckets][i]
		}

		colorbrewerWithNull[numLegendBuckets] = "rgb(170,170,170)"; 

		//remove any residual rectangles
		
		legendG.selectAll("text")
			.remove()
		legendG.selectAll("rect")
			.remove()

		legendRects = legendG.selectAll("rect")
			.data(colorbrewerWithNull)
			.enter().append("rect")

		//populate legend rectangles - remember, (0,0) is top left
		legendRects.attr("class", "legendRect")
			.attr("x",legendLeftMargin)
			.attr("y", function(d,i){return legendInsideMargin/2 + i*(legendRectHeight + legendInsideMargin)})
			.attr("height", legendRectHeight)
			.attr("width", legendRectWidth)	
			.attr("rx",3)
			.style("fill", function(d){ return d})
			.style("fill-opacity",.8)

		//dynamically build the legend labels
		//remember arrays in JS are passed by REFERENCE. Don't screw up the original scale!
		legendTextValues = colorScale.copy().quantiles();
		legendTextValues.unshift(roundNumberExtents[0]) //add to the beginning
		legendTextValues.push(roundNumberExtents[1])  //add to the end

		//generate the labels
		var legendTextArray = [];
		for(i = 0; i<numLegendBuckets; i++){
			if(i==(numLegendBuckets-1)){
				legendTextArray[i] = '$' + moneyFmt(Math.ceil(legendTextValues[i])) + " - $" + moneyFmt(Math.ceil(legendTextValues[i+1])); 
			} else {

				legendTextArray[i] = '$' + moneyFmt(Math.ceil(legendTextValues[i])) + " - $" + moneyFmt(Math.floor(legendTextValues[i+1])-1); 
			}
		}
		legendTextArray.push("No Data") //To explain if a block isn't colored in

		legendText = legendG.selectAll("text")
			.data(legendTextArray)
			.enter().append("text")
			.attr("class", "legendText")
			.attr("x", legendLeftMargin + legendRectWidth + 5)
			.attr("y", function(d,i){return legendInsideMargin +i*(legendRectHeight + legendInsideMargin) + legendRectHeight/2})
			.text(function(d){return d});
	
		/* this doesn't work, a 'would be nice'	- currently hardcoded with a global		

		//all the labels are drawn, so let's go back through and figure out			
		// how wide the div should be to contain them

		var legendWidth = 0;
		legendText.each(function(){
			labelWidth = this.getComputedTextLength();
			console.log('labelWidth '+labelWidth);
			if(legendWidth < labelWidth){
				legendWidth = labelWidth;}})
		
		console.log("legendWidth: " + legendWidth);

		d3.select(".colorLegend")
			.transition()
			.attr("width",legendWidth + 55);
		console.log("legendW "+ legendWidth + ' '+55)
		legendSVG.transition()
			.attr("width",legendWidth + 55);
*/
	}

	function StateToggle() {
		//turn off the HRRs, before the colorbrewer scale is set for states. Else you'll have the
		// HRR color scale regardless of whether it makes sense for the state numbers
		if(stateColorStatus == 0){

			if(HRRstatus == 1){
				HRRToggle();
			}

			stateAreas = stateG.selectAll("path")
				.on("mouseover",function(d){
					var stateName = d.properties.name;
					var stateDataObject = statesByDRGByStateByStatusByType[currentDRG][stateName][currentStatus]

					if(pointStatus == 0){
						stateColor = (d3.select(this).style("fill"));
						d3.select(this).style("fill","brown")
					}

					d3.select("#regionBox").select("hr")
						.style("display","block")

					//Labels the infobox with data from the GeoJSON file
					d3.select("#regionName")
						.append("span")
						.attr("class","regionTitle")
						.text(stateBeautifier(d.properties.name));
		
					//This bit dynamically populates the different elements of the table.
					// Class and ID values are set (and can be reset) to ease styling via CSS.

					total = sumAcrossFileTypes(stateDataObject)['Total'];
					availableFileTypes = Object.keys(stateDataObject)

					var trBody = d3.select("#regionOverallTbody").selectAll(".stateTr");

					trBody.data(availableFileTypes)
						.enter()
						.append("tr").attr("class","stateTr")
						.append("td").attr("class","stateTd")
						.text(function(d){
							return d.capitalize()});
							
					d3.selectAll(".stateTr")
						.append("td")
						.text(function(d){
							return '$'+moneyFmt(d3.round(stateDataObject[d].epcost,2))});

					d3.selectAll(".stateTr")
						.append("td")
						.attr("class","percent")
						.text(function(d){
							value = d3.round(stateDataObject[d].epcost/total,4);
							if(value <= 100) {						
								return '('+percentFmt(value)+')'}
							return '('+100+'%)' //prevents embarassment if a component is slightly >100%
					})

					d3.select("#regionOverallTbody").append("tr")
						.attr("class","totalTr")
						.append("td")
						.text("Total")

					d3.select(".totalTr")
						.append("td")
						.attr("class","totalValue")
						.text('$' + moneyFmt(d3.round(total,2)) )
				
					d3.select("#regionOverallTbody").append("tr")
						.append("td")
						.attr("colspan",3)
						.attr("id","compareToMean")
						.text(percentFmt(d3.round(total/nationalMean,4))+ " of US Mean")
						.attr("class",function(){
							if(total/nationalMean < 1){
								return "belowMean"}
							else if(total/nationalMean == 1){
								return "atMean"}
							return "aboveMean"})

					
					//histogram pointers
					val = sumFileTypes(stateDataObject)


					regionTriangle = d3.select("#barChartSVG").append("g")
						.attr("class","regionTriangle")

					//you have to draw the triangle from scratch: starting position, second, third
					// separated by l if second and third are relative, L if absolute. Close shape with 'z'.

					regionTriangle.append("path")
						.attr('d', function(d){
							return 'M ' + histAxisScale(sumFileTypes(stateDataObject))+' ' + 30 + ' l 15 -40 l -30 0 z'})
						.attr("class","regionTriangle")

				})
				.on("mouseout", function(){
					if(pointStatus == 0){
						d3.select(this).style("fill",stateColor);
					}
					
					d3.select("#regionBox").select("hr")
						.style("display","none")
					d3.selectAll("tr").remove();
					d3.select("#instanceLine").remove();
					d3.select(".regionTitle").remove();
					d3.select(".regionTriangle").remove();
				})

		refreshStates();
		stateColorStatus = 1;

		} else {
			stateAreas.transition()
				.style("fill", "#000")
				.style("fill-opacity",.2)

			d3.select(".colorLegend").style("background","rgba(255,255,255,0)")
			d3.select("#legendTitleText")
				.style("display","none");
			legendRects.remove();
			legendText.remove();

			stateColorStatus = 0;
		}
	} // end StateToggle()
	
	function HRRToggle(){
		if(HRRstatus == 0){

			if(stateColorStatus == 1){
				StateToggle();
			}

		var HRRColor;

		//prevents mouseover trouble - the functions defined for states shouldn't fire in HRR mode
		stateAreas = stateG.selectAll("path")
			.on("mouseover",function(d){})
			.on("mouseout",function(d){})

		HRRareas = hrrG.selectAll("path")
			.style("display","block")
			.transition()
			.duration(200)

		HRRareas = hrrG.selectAll("path")
			.on("mouseover",function(d){
				var HRRName = d.properties.HRRNUM;
			
				//a lot of HRRs may be missing - will have to manage the errors
				if(HRRsByDRGByHRRByStatusByType[currentDRG][HRRName] != undefined){

					var HRRDataObject = HRRsByDRGByHRRByStatusByType[currentDRG][HRRName][currentStatus]
					if(pointStatus == 0){
						HRRColor = (d3.select(this).style("fill"));
						d3.select(this).style("fill","brown")
					}

					d3.select("#regionBox").select("hr")
						.style("display","block")

					//Labels the infobox with data from the GeoJSON file

					d3.select("#regionName")						
						.append("span")
						.attr("class","regionTitle")
						.text(stateBeautifier(d.properties.HRRCITY.substring(0,2))+'- '+d.properties.HRRCITY.substring(3,d.properties.HRRCITY.length));
		
					//This bit dynamically populates the different elements of the table.
					// Class and ID values are set (and can be reset) to ease styling via CSS.

					total = sumAcrossFileTypes(HRRDataObject)['Total'];
					availableFileTypes = Object.keys(HRRDataObject)

					var trBody = d3.select("#regionOverallTbody").selectAll(".stateTr");

					trBody.data(availableFileTypes)
						.enter()
						.append("tr").attr("class","stateTr")
						.append("td").attr("class","stateTd")
						.text(function(d){
							return d.capitalize()});
							
					d3.selectAll(".stateTr")
						.append("td")
						.text(function(d){
							return '$'+moneyFmt(d3.round(HRRDataObject[d].epcost,2))});

					d3.selectAll(".stateTr")
						.append("td")
						.attr("class","percent")
						.text(function(d){
							value = d3.round(HRRDataObject[d].epcost/total,4)
							if(value <= 100) {						
								return '('+percentFmt(value)+')'}

							return '('+100+'%)' //prevents embarrassment if a component is slightly >100% due to a rounding issue
					})

					d3.select("#regionOverallTbody").append("tr")
						.attr("class","totalTr")
						.append("td")
						.text("Total")

					d3.select(".totalTr")
						.append("td")
						.attr("class","totalValue")
						.text('$' + moneyFmt(d3.round(total,2)) )

					
					d3.select("#regionOverallTbody").append("tr")
						.append("td")
						.attr("colspan",3)
						.attr("id","compareToMean")
						.text(percentFmt(d3.round(total/nationalMean,4))+ " of National Average")
						.attr("class",function(){
							if(total/nationalMean < 1){
								return "belowMean"}
							else if(total/nationalMean == 1){
								return "atMean"}
							return "aboveMean"})

					//histogram pointer
					val = sumFileTypes(HRRDataObject)

					regionTriangle = d3.select("#barChartSVG").append("g")
						.attr("class","regionTriangle")
	
					regionTriangle.append("path")
						.attr('d', function(d){
							return 'M ' + histAxisScale(sumFileTypes(HRRDataObject))+' ' + 30 + ' l 15 -40 l -30 0 z'})
						.attr("class","regionTriangle")

				} //end if
			}) //end on("mouseover")
			.on("mouseout", function(){
				if(pointStatus == 0){
					d3.select(this).style("fill",HRRColor);
				}
				HRRColor = "none"
				d3.select("#regionBox").select("hr")
					.style("display","none")
				d3.selectAll("tr").remove();
				d3.select("#instanceLine").remove();
				d3.select(".regionTitle").remove();
				d3.select(".regionTriangle").remove();
			})

		refreshHRRs();
		HRRstatus = 1;
		} else {

			d3.selectAll(".HRRclass")
				.transition()
				.duration(200)
				.style("display","none");

			d3.select(".colorLegend").style("background","rgba(255,255,255,0)")
			d3.select("#legendTitleText")
				.style("display","none");

			legendText.remove();
			legendRects.remove();
			HRRstatus = 0;
		}
	} //end HRRToggle();
	
	function PointToggle(){
		if(pointStatus == 0){	
			providerDots.style("display","block");
			pointStatus = 1;
		} else {
			providerDots.style("display","none")
			pointStatus = 0;
		}
	}	

	function DRGBoxControl(elem,node){
		//make checkboxes behave like radio buttons - mutually exclusive
		d3.selectAll(".drg")
			.attr("checked", function(){
				if(this != elem){
					this.checked = false;}
				})
		currentDRG = node;

		if(HRRstatus==1){
			refreshHRRs()}
		else if(stateColorStatus==1){
			refreshStates();}
	}

	function statusBoxControl(elem,node){
		//make checkboxes behave like radio buttons - mutually exclusive
		d3.selectAll(".status")
			.attr("checked", function(){
				if(this != elem){
					this.checked = false;}
				})
		currentStatus = node;

		if(stateColorStatus ==1){
			refreshStates();} 
		else if(HRRstatus==1){
			refreshHRRs();}
	}

//Helper functions
	function getRegionColor(regionName,colorObject){
		//maybe a function is overkill, allows for future flexibility though
		return colorObject[regionName];
	}

	function formatData(d){

		var formattedObject = {};
		formattedObject.drg = d[0].drg
		formattedObject.epcost= d[0].epcost
		formattedObject.state = d[0].state
		formattedObject.type = d[0].type
		
		return formattedObject;
	}
	
	function defineColorScale(regionValueArray,listOfRegions,numLegendBuckets){

	/* The original cloropleth example used the colorbrewer object as a direct input to colorScale.range(). 
		This, combined with the quantile nature of the colorScale (I tried with d3.scale.linear, it 
		didn't work well) induced me to rewrite some of the logic that assigns values to color. The result
		is that the color buckets are now evenly spaced and represent equal amounts of the domain.*/ 

		var displayedValues = {}; //this object will act as a regionID:color hash

		valuesRegionsTake = regionValueArray;
		colorScale.domain(roundExtents(d3.extent(d3.values(regionValueArray)))); //set endpoints

		var bucketHolder = [];
	
		for(var i = 0; i<numLegendBuckets; i++){
			bucketHolder.push(i); //populate with bucket indices
		}

		colorScale.range(bucketHolder);

		var bucket;

		for(var i = 0; i < listOfRegions.length; i++){
			bucket = colorScale(regionValueArray[listOfRegions[i]])
			displayedValues[listOfRegions[i]] = colorbrewer[themeselection][numLegendBuckets][bucket]
		}
	
		return displayedValues;
	}

	function roundExtents(incomingExtent){
		//expands a two-element array (an extent) to the next roundest values
		var max = incomingExtent[1];
		var magnitude = -2;

		while(max > 1) { 
			magnitude++;
			max = max/10
		}
		
		factor = Math.pow(10,magnitude)
		
		var outgoingExtent = [];
		outgoingExtent[0] = Math.floor(incomingExtent[0]/factor)*factor;
		outgoingExtent[1] = Math.ceil(incomingExtent[1]/factor)*factor;
		
		return outgoingExtent;
	}

	function sumFileTypes(objectData){
		typesInObject = Object.keys(objectData);
		var fileTypeSum = 0;
		
		if(objectData.fileTypeSum){
			return objectData.fileTypeSum;}

		for(var i = 0; i < typesInObject.length; i++){
				
			fileTypeSum += objectData[typesInObject[i]].epcost;
		}
	
		return fileTypeSum;
	}

	String.prototype.capitalize = function(){
		return this.charAt(0).toUpperCase() + this.slice(1);
	}
	
	//intentionally empty so you can capitalize() with abandon and not have to check types
	Number.prototype.capitalize = function(){
		return this;
	}

	function sumAcrossFileTypes(regionObject){
		fileTypeKeys = Object.keys(regionObject)
		objectWithTotals = {};	
	
		var fileTypeTotal = 0;
		var regionValue = 0;

		for(var k=0; k<fileTypeKeys.length; k++){
			regionValue = regionObject[fileTypeKeys[k]].epcost;
			objectWithTotals[fileTypeKeys[k]] = regionValue;
			fileTypeTotal += regionValue;
		}
		
		objectWithTotals['Total'] = fileTypeTotal;
		
		return objectWithTotals;

	}

	function buildOverallStatus(nestObject){
		drgList = Object.keys(nestObject)

		for(var i = 0; i< drgList.length; i++){
			regionList = Object.keys(nestObject[drgList[i]])

			for(var j = 0; j< regionList.length; j++){
				var regionTotal = 0;
				regionOverallObject = {};

				statusList = Object.keys(nestObject[drgList[i]][regionList[j]])

				for(var k = 0; k<statusList.length; k++){

					totalAmongFiletypes = sumFileTypes(nestObject[drgList[i]][regionList[j]][statusList[k]]);
					regionOverallObject[statusList[k]] = {};
					regionOverallObject[statusList[k]]['epcost'] = totalAmongFiletypes;
				}

				nestObject[drgList[i]][regionList[j]]['overall'] = regionOverallObject;
			}
		}
		return nestObject;
	}

	function stateBeautifier(abbr){
		var stateNames = {
		 "AL": "Alabama",
		 "AK":  "Alaska",
		 "AZ":  "Arizona",
		 "AR":  "Arkansas",
		 "CA":  "California",
		 "CO":  "Colorado",
		 "CT":  "Connecticut",
		 "DE":  "Delaware",
		 "DC":  "District Of Columbia",
		 "FL":  "Florida",
		 "GA":  "Georgia",
		 "HI":  "Hawaii",
		 "ID":  "Idaho",
		 "IL":  "Illinois",
		 "IN":  "Indiana",
		 "IA":  "Iowa",
		 "KS":  "Kansas",
		 "KY":  "Kentucky",
		 "LA":  "Louisiana",
		 "ME":  "Maine",
		 "MD":  "Maryland",
		 "MA":  "Massachusetts",
		 "MI":  "Michigan",
		 "MN":  "Minnesota",
		 "MS":  "Mississippi",
		 "MO":  "Missouri",
		 "MT":  "Montana",
		 "NE":  "Nebraska",
		 "NV":  "Nevada",
		 "NH":  "New Hamspire",
		 "NJ":  "New Jersey",
		 "NM":  "New Mexico",
		 "NY":  "New York",
		 "NC":  "North Carolina",
		 "ND":  "North Dakota",
		 "OH":  "Ohio",
		 "OK":  "Oklahoma",
		 "OR":  "Oregon",
		 "PA":  "Pennsylvania",
		 "RI":  "Rhode Island",
		 "SC":  "South Carolina",
		 "SD":  "South Dakota",
		 "TN":  "Tennessee",
		 "TX":  "Texas",
		 "UT":  "Utah",
		 "VT":  "Vermont",
		 "VA":  "Virginia",
		 "WA":  "Washington",
		 "WV":  "West Virginia",
		 "WI":  "Wisconsin",
		 "WY":  "Wyoming"}
		return stateNames[abbr];
	}

</script>

  

	</div><!--end content-->
