xquery version "3.0";

module namespace geo="http://syriaca.org/geojson";
(:~
 : Module returns coordinates for leafletjs maps, or for API requests
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2014-06-25
:)

import module namespace xqjson="http://xqilla.sourceforge.net/lib/xqjson";
import module namespace global="http://syriaca.org/global" at "global.xqm";

declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace transform="http://exist-db.org/xquery/transform";

(:~
 : Module builds GEOJSON features element for each place returned
 : @param $geo coordinates string
 : @param $id  record id 
 : @param $rec-type place type
 : @param $title place title
:)
declare function geo:build-json($geo as xs:string, $id as xs:string, $rec-type as xs:string, $title as xs:string, $rec-rel as xs:string) as element(features){    
    <item type="object">
        <pair name="type"  type="string">Feature</pair>
        <pair name="geometry"  type="object">
            <pair name="type"  type="string">Point</pair>
            <pair name="coordinates"  type="array">
                <item type="number">{substring-after($geo,' ')}</item>
                <item type="number">{substring-before($geo,' ')}</item>
            </pair>
        </pair>
        <pair name="properties"  type="object">
            <pair name="uri"  type="string">{replace($id,$global:base-uri,$global:nav-base)}</pair>
            <pair name="placeType"  type="string">{if($rec-type='open-water') then 'openWater' else $rec-type}</pair>
            {
              if($rec-rel != '') then 
                <pair name="relation"  type="string">{$rec-rel}</pair>
              else ()  
            }
            <pair name="name"  type="string">{$title} - {if($rec-type='open-water') then 'openWater' else $rec-type}</pair>
        </pair>
    </item>
};

(:~
 : Module builds KML Placemark element for each place returned
 : @param $geo coordinates string
 : @param $id  record id 
 : @param $rec-type place type
 : @param $title place title
:)
declare function geo:build-kml($geo as xs:string,$id as xs:string, $rec-type as xs:string, $title as xs:string) as element(features){
    <kml xmlns="http://www.opengis.net/kml/2.2">
        <Placemark>
            <name>{$title} - {if($rec-type='open-water') then 'openWater' else $rec-type}</name>
            <description>{replace($id,$global:base-uri,$global:nav-base)}</description>
            <Point>
                <coordinates>{replace($geo,' ',',')}</coordinates>
            </Point>
        </Placemark>
    </kml>    
};

(:~
 : Build results set for geographic data, or passes in results from search 
 : @param $geo-search predefined results set passed from search.xqm
 : @param $type place type from predefined list: http://syriaca.org/documentation/place-types.html
 : @param $output indicates json or kml
:)
declare function geo:get-coordinates($geo-search as element()*, $type as xs:string*, $output as xs:string*) as element()*{
    let $geo-map :=  map{"geo-data" := $geo-search}        
    for $place-name in map:get($geo-map, 'geo-data')
    let $id := string($place-name/ancestor::tei:place/tei:idno[@type='URI'][starts-with(.,$global:base-uri)])
    let $rec-type := string($place-name/ancestor::tei:place/@type)
    let $title := $place-name/ancestor::tei:place/tei:placeName[@xml:lang = 'en'][1]/text()
    let $geo := $place-name
    let $rel := string($place-name/ancestor::*:relation/@name)
    return
        if($output = 'kml') then geo:build-kml($geo,$id,$rec-type,$title)
        else geo:build-json($geo,$id,$rec-type,$title,$rel)
};

(:~
 : Build root element for KML output
 : @param $geo-search predefined results set passed from search.xqm
 : @param $type place type from predefined list: http://syriaca.org/documentation/place-types.html
 : @param $output indicates json or kml
:)
declare function geo:kml-wrapper($geo-search as element()*, $type as xs:string*, $output as xs:string*) as element()*{
    <kml xmlns="http://www.opengis.net/kml/2.2">
        <Document>
            {geo:get-coordinates($geo-search,$type,$output)}
        </Document>
    </kml>
};

(:~
 : Build root element for geojson output
 : @param $geo-search predefined results set passed from search.xqm
 : @param $type place type from predefined list: http://syriaca.org/documentation/place-types.html
 : @param $output indicates json or kml
:)
declare function geo:json-wrapper($geo-search as element()*, $type as xs:string*, $output as xs:string*) as element()*{
    <json type="object">
        <pair name="type" type="string">FeatureCollection</pair>
        <pair name="features"  type="array">
            {geo:get-coordinates($geo-search,$type,$output)}
        </pair>
    </json>
};

(:~
 : Transform results to json with xslt for inclusion in search page. 
 : @param $geo-search predefined results set passed from search.xqm
 : @param $type place type from predefined list: http://syriaca.org/documentation/place-types.html
 : @param $output indicates json or kml
:)
declare function geo:json-transform($geo-search as node()*, $type as xs:string*, $output as xs:string*){
    xqjson:serialize-json(geo:json-wrapper($geo-search, $type, $output))
};

(:~
 : Selects map rendering based on config.xml entry
:)
declare function geo:build-map($geo-search as node()*, $type as xs:string*, $output as xs:string*){
if($global:app-map-option = 'google') then geo:build-google-map($geo-search, $type, $output)
else geo:build-leaflet-map($geo-search, $type, $output)
};

declare function geo:build-leaflet-map($geo-search as node()*, $type as xs:string*, $output as xs:string*){
    <div id="map-data" style="margin-bottom:3em;">
        <script type="text/javascript" src="http://cdn.leafletjs.com/leaflet-0.7.2/leaflet.js?2"/>
        <script src="http://isawnyu.github.com/awld-js/lib/requirejs/require.min.js" type="text/javascript"/>
        <script src="http://isawnyu.github.com/awld-js/awld.js?autoinit" type="text/javascript"/>
        <script type="text/javascript" src="/exist/apps/srophe/resources/leaflet/leaflet.awesome-markers.js"/>
        <div id="map"/>
        <div class="hint map pull-right">* {count($geo-search)} have coordinates and are shown on this map. 
             <button class="btn btn-link" data-toggle="modal" data-target="#map-selection" id="mapFAQ">Read more...</button>
        </div>
        <script type="text/javascript">
            <![CDATA[
            var terrain = L.tileLayer('http://api.tiles.mapbox.com/v3/sgillies.map-ac5eaoks/{z}/{x}/{y}.png', {attribution: "ISAW, 2012"});
                                
            /* Not added by default, only through user control action */
            var streets = L.tileLayer('http://api.tiles.mapbox.com/v3/sgillies.map-pmfv2yqx/{z}/{x}/{y}.png', {attribution: "ISAW, 2012"});
                                
            var imperium = L.tileLayer('http://pelagios.dme.ait.ac.at/tilesets/imperium//{z}/{x}/{y}.png', {attribution: 'Tiles: &lt;a href="http://pelagios-project.blogspot.com/2012/09/a-digital-map-of-roman-empire.html"&gt;Pelagios&lt;/a&gt;, 2012; Data: NASA, OSM, Pleiades, DARMC', maxZoom: 11 });
                                
            var placesgeo = ]]>{xqjson:serialize-json(geo:json-wrapper($geo-search, $type, $output))}
            <![CDATA[                                
            var sropheIcon = L.Icon.extend({
                                            options: {
                                                iconSize:     [38, 38],
                                                iconAnchor:   [22, 94],
                                                popupAnchor:  [-3, -76]
                                                }
                                            });
                                            var redIcon =
                                                L.AwesomeMarkers.icon({
                                                    icon:'fa-circle',
                                                    markerColor: 'red'
                                                }),
                                            orangeIcon =  
                                                L.AwesomeMarkers.icon({
                                                    icon:'fa-circle',
                                                    markerColor: 'orange'
                                                }),
                                            purpleIcon = 
                                                L.AwesomeMarkers.icon({
                                                    icon:'fa-circle',
                                                    markerColor: 'purple'
                                                }),
                                            blueIcon =  L.AwesomeMarkers.icon({
                                                    icon:'fa-circle',
                                                    markerColor: 'blue'
                                                });
                                        
            var geojson = L.geoJson(placesgeo, {onEachFeature: function (feature, layer){
                                            var popupContent = "<a href='" + feature.properties.uri + "'>" +
                                            feature.properties.name + " - " + feature.properties.type + "</a>";
                                            layer.bindPopup(popupContent);
                                            switch (feature.properties.relation) {
                                                case 'born-at': return layer.setIcon(orangeIcon);
                                                case 'died-at':   return layer.setIcon(redIcon);
                                                case 'has-literary-connection-to-place':   return layer.setIcon(purpleIcon);
                                                case 'has-relation-to-place':   return layer.setIcon(blueIcon);
                                            }
                                            
                                        }
                                })
        var map = L.map('map').fitBounds(geojson.getBounds(),{maxZoom: 5});     
        terrain.addTo(map);
                                        
        L.control.layers({
                        "Terrain (default)": terrain,
                        "Streets": streets,
                        "Imperium": imperium }).addTo(map);
        geojson.addTo(map);     
        ]]>
        </script>
         <div>
            <div class="modal fade" id="map-selection" tabindex="-1" role="dialog" aria-labelledby="map-selectionLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal">
                                <span aria-hidden="true"> x </span>
                                <span class="sr-only">Close</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <div id="popup" style="border:none; margin:0;padding:0;margin-top:-2em;"/>
                        </div>
                        <div class="modal-footer">
                            <a class="btn" href="/documentation/faq.html" aria-hidden="true">See all FAQs</a>
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
         </div>
         <script type="text/javascript">
         <![CDATA[
            $('#mapFAQ').click(function(){
                $('#popup').load( '../documentation/faq.html #map-selection',function(result){
                    $('#map-selection').modal({show:true});
                });
             });]]>
         </script>
    </div> 
};


(:~
 : Pass geojson to google maps
 : @param $geo-search predefined results set passed from search.xqm
 : @param $type place type from predefined list: http://syriaca.org/documentation/place-types.html
 : @param $output indicates json or kml
:)
declare function geo:build-google-map($geo-search as node()*, $type as xs:string*, $output as xs:string*){
    <div id="map-data" style="margin-bottom:3em;">
        <script src="http://maps.googleapis.com/maps/api/js">//</script>
        <div id="map"/>
        <div class="hint map pull-right">* {count($geo-search)} have coordinates and are shown on this map. 
             <button class="btn btn-link" data-toggle="modal" data-target="#map-selection" id="mapFAQ">Read more...</button>
        </div>
    
        <script type="text/javascript">
            <![CDATA[
            var map;
                            
            var bounds = new google.maps.LatLngBounds();
            
            function initialize(){
                map = new google.maps.Map(document.getElementById('map'), {
                    zoom: 2,
                    center: new google.maps.LatLng(0,0),
                    mapTypeId: google.maps.MapTypeId.TERRAIN
                });

                var placesgeo = ]]>{xqjson:serialize-json(geo:json-wrapper($geo-search, $type, $output))}
                <![CDATA[ 
                
                var infoWindow = new google.maps.InfoWindow();
                
                for(var i = 0, length = placesgeo.features.length; i < length; i++) {
                    var data = placesgeo.features[i]
                    var coords = data.geometry.coordinates;
                    var latLng = new google.maps.LatLng(coords[1],coords[0]);
                    var marker = new google.maps.Marker({
                        position: latLng,
                        map:map
                    });
                    
                    // Creating a closure to retain the correct data, notice how I pass the current data in the loop into the closure (marker, data)
         			(function(marker, data) {
         
         				// Attaching a click event to the current marker
         				google.maps.event.addListener(marker, "click", function(e) {
         					infoWindow.setContent("<a href='" + data.properties.uri + "'>" + data.properties.name + " - " + data.properties.type + "</a>");
         					infoWindow.open(map, marker);
         				});
         
         
         			})(marker, data);
                    bounds.extend(latLng);
                }
                map.fitBounds(bounds);
            }

            google.maps.event.addDomListener(window, 'load', initialize)

        ]]>
        </script>
         <div>
            <div class="modal fade" id="map-selection" tabindex="-1" role="dialog" aria-labelledby="map-selectionLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal">
                                <span aria-hidden="true"> x </span>
                                <span class="sr-only">Close</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <div id="popup" style="border:none; margin:0;padding:0;margin-top:-2em;"/>
                        </div>
                        <div class="modal-footer">
                            <a class="btn" href="/documentation/faq.html" aria-hidden="true">See all FAQs</a>
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
         </div>
         <script type="text/javascript">
         <![CDATA[
            $('#mapFAQ').click(function(){
                $('#popup').load( '../documentation/faq.html #map-selection',function(result){
                    $('#map-selection').modal({show:true});
                });
             });]]>
         </script>
    </div> 
};