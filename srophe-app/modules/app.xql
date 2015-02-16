xquery version "3.0";

module namespace app="http://syriaca.org//templates";
(:~
 : General use xqueries for accross srophe app.
:)
import module namespace teiDocs="http://syriaca.org//teiDocs" at "teiDocs/teiDocs.xqm";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://syriaca.org//config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";

(:~
 : Transform tei to html
 : @param $node data passed to transform
:)
declare function app:tei2html($nodes as node()*) {
    transform:transform($nodes, doc('../resources/xsl/tei2html.xsl'),() )
};

declare %templates:wrap function app:set-data($node as node(), $model as map(*), $doc as xs:string){
    teiDocs:generate-docs('/db/apps/srophe/data/places/tei/78.xml')
};

(:~
 : Builds page title
 : Otherwise build based on page url
 : @param $metadata:id gets place id from url
 :)
declare %templates:wrap function app:page-title(){
'Title'
};

(:~
 : Builds Dublin Core metadata
 : If id parameter is present use place data to generate metadata
 : @param $metadata:id gets place id from url
 :) 
declare function app:get-dc-metadata(){
    if(exists($id)) then 'get data'
    else ()
};
(:
 : @depreciated
 : use tei2html.xslt
 : Currently used by spear only
:)
declare function app:link-icons-inline($nodes, $resource-id){
<div id="link-icons" class="col-md-4 text-right">
   {
    let $link-title := $nodes//tei:place/tei:placeName[@xml:lang='en'][1] | $nodes//tei:person/tei:persName[@xml:lang='en'][1]
    let $resource-uri := 'place/'
    return 
        (
        app:pleiades-links($nodes/descendant::tei:idno[contains(.,'pleiades')], $link-title,'inline'),
        app:wikipedia-links($nodes/descendant::tei:idno[contains(.,'wikipedia')],'inline'),
        app:google-map-links($nodes/descendant::tei:location[@type='gps']/tei:geo,$link-title,$resource-uri, $resource-id,'inline'),
        <a href="{$resource-uri}/tei" rel="alternate" type="application/tei+xml"><img src="/exist/apps/srophe/resources/img/tei-25.png" alt="The Text Encoding Initiative icon" title="click to view the TEI XML source data for this place"/></a>,
        <a href="{$resource-uri}/atom" rel="alternate" type="application/atom+xml"><img src="/exist/apps/srophe/resources/img/atom-25.png" alt="The Atom format icon" title="click to view this data in Atom XML format"/></a>,
        <a href="javascript:window.print();"><img src="/exist/apps/srophe/resources/img/icons-print.png" alt="The Print format icon" title="click to send this page to the printer"/></a>
        )    
    }
</div>
};

declare function app:link-icons-list($nodes, $resource-id){
<div id="see-also" class="well">
   <h3>See Also</h3>
   {
    let $link-title := $nodes//tei:place/tei:placeName[@xml:lang='en'][1] | $nodes//tei:person/tei:persName[@xml:lang='en'][1]
    let $resource-uri := 'place/'
    return
        <ul>
            {
            (app:pleiades-links($nodes/descendant::tei:idno[contains(.,'pleiades')], $link-title, 'list'),
            app:viaf-links($nodes/descendant::tei:idno[contains(.,'http://viaf.org/')]),
            app:wikipedia-links($nodes/descendant::tei:idno[contains(.,'wikipedia')],'list'),
            app:google-map-links($nodes/descendant::tei:location[@type='gps']/tei:geo, $link-title, $resource-uri, $resource-id,'list')
            )
            }
            <li><a href="{$resource-uri}/tei" rel="alternate" type="application/tei+xml">TEI XML source data for this resource</a></li>
            <li><a href="{$resource-uri}/atom" rel="alternate" type="application/atom+xml">Atom XML format</a></li>
        </ul>   
    }
</div>
};

declare function app:viaf-links($nodes){
for $node in $nodes
return 
   <li><a href="{normalize-space(.)}">VIAF</a></li>
};

declare function app:pleiades-links($nodes, $link-title, $mode){
for $node in $nodes
return 
    if($mode = 'top') then 
        <a href="{normalize-space(.)}"><img src="/exist/apps/srophe/resources/img/circle-pi-25.png" alt="Image of the Greek letter pi in blue; small icon of the Pleiades project" title="click to view {$link-title} in Pleiades"/></a>
    else <li><a href="{normalize-space(.)}">{$link-title} in Pleiades</a></li>
};

declare function app:wikipedia-links($nodes, $mode){
for $node in $nodes
let $title := replace(tokenize(.,'/')[last()],'_',' ')
return 
    if($mode = 'top') then 
        <a href="{normalize-space(.)}"><img src="/exist/apps/srophe/resources/img/Wikipedia-25.png" alt="The Wikipedia icon" title="click to view {$title} in Wikipedia"/></a>
    else <li><a href="{normalize-space(.)}">{$title} in Wikipedia</a></li>        
};

declare function app:google-map-links($nodes, $link-title, $resource-uri, $resource-id, $mode){
for $node in $nodes
return
    if($mode = 'top') then 
        <a href="https://maps.google.com/maps?f=q&amp;hl=en&amp;z=4&amp;q=http://syriaca.org/geo/atom.xql?id={$resource-id}">
            <img src="/exist/apps/srophe/resources/img/gmaps-25.png" alt="The Google Maps icon" title="click to view {$link-title} on Google Maps"/>
        </a>
    else 
    <li>
        <a href="https://maps.google.com/maps?f=q&amp;hl=en&amp;z=4&amp;q=http://syriaca.org/geo/atom.xql?id={$resource-id}">
            {$link-title} on Google Maps
        </a>
    </li> 
};


(:~
 : Generic contact form can be added to any page by calling:
 : <div data-template="app:contact-form"/>
 : with a link to open it that looks like this: 
 : <button class="btn btn-default" data-toggle="modal" data-target="#feedback">CLink text</button>&#160;
:)
declare %templates:wrap function app:contact-form($node as node(), $model as map(*))
{
    <div> 
        <div class="modal fade" id="feedback" tabindex="-1" role="dialog" aria-labelledby="feedbackLabel" aria-hidden="true">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <button type="button" class="close" data-dismiss="modal">
                            <span aria-hidden="true">x</span>
                            <span class="sr-only">Close</span>  
                        </button>
                        <h2 class="modal-title" id="feedbackLabel">Corrections/Additions?</h2>
                    </div>
                    <form action="/exist/apps/srophe/modules/email.xql" method="post" id="email" role="form">
                        <div class="modal-body" id="modal-body">
                            <input type="text" name="name" placeholder="Name" class="form-control" style="max-width:300px"/>
                            <br/>
                            <input type="text" name="email" placeholder="email" class="form-control" style="max-width:300px"/>
                            <br/>
                            <input type="text" name="subject" placeholder="subject" class="form-control" style="max-width:300px"/>
                            <br/>
                            <textarea name="comments" id="comments" rows="3" class="form-control" placeholder="Comments" style="max-width:500px"/>
                            <!-- start reCaptcha API-->
                            <script type="text/javascript" src="http://api.recaptcha.net/challenge?k=6Lf1uvESAAAAAPiMWhCCFcyDqj8LVNoBKwkROCia"/>
                            <noscript>
                                <iframe src="http://api.recaptcha.net/noscript?k=6Lf1uvESAAAAAPiMWhCCFcyDqj8LVNoBKwkROCia" height="100" width="100" frameborder="0"/>
                                <br/>
                                <textarea name="recaptcha_challenge_field" rows="3" cols="40"/>
                                <input type="hidden" name="recaptcha_response_field" value="manual_challenge"/>
                            </noscript>
                        </div>
                        <div class="modal-footer">
                            <button class="btn btn-default" data-dismiss="modal">Close</button>
                            <input id="email-submit" type="submit" value="Send e-mail" class="btn"/>
                        </div>
                  </form>
          </div>
       </div>
        </div>
   </div> 
};

(:~
 : Grabs latest news for home page
 : http://syriaca.org/feed/
 :)
 
declare %templates:wrap function app:get-feed($node as node(), $model as map(*)){ 
   let $news := doc('http://syriaca.org/blog/feed/')/child::*
   for $latest at $n in subsequence($news//item, 1, 8)
   return 
   <li>
        <a href="{$latest/link/text()}">{$latest/title/text()}</a>
   </li>
};

(:~
 : Typeswitch to transform confessions.xml into nested list.
 : @param $node   
:)
declare function app:transform($nodes as node()*) as item()* {
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(tei:list) return element ul {app:transform($node/node())}
            case element(tei:item) return element li {app:transform($node/node())}
            case element(tei:label) return element span {app:transform($node/node())}
            default return app:transform($node/node())
};

(:~
 : Pull confession data for confessions.html
:)
declare %templates:wrap function app:build-confessions($node as node(), $model as map(*)){
    let $confession := doc('/db/apps/srophe/documentation/confessions.xml')//tei:body/child::*[1]
    return app:transform($confession)
};

(:~
 : get editors as distinct values
:)
declare function app:get-editors(){
distinct-values(
    (for $editors in collection('/db/apps/srophe/data/places/tei')//tei:respStmt/tei:name/@ref
     return substring-after($editors,'#'),
     for $editors-change in collection('/db/apps/srophe/data/places/tei')//tei:change/@who
     return substring-after($editors-change,'#'))
    )
};

(:~
 : Build editor list. Sort alphabeticaly
:)
declare %templates:wrap function app:build-editor-list($node as node(), $model as map(*)){
    let $editors := doc('/db/apps/srophe/documentation/editors.xml')//tei:listPerson
    for $editor in app:get-editors()
    let $name := 
        for $editor-name in $editors//tei:person[@xml:id = $editor]
        return concat($editor-name/tei:persName/tei:forename,' ',$editor-name/tei:persName/tei:addName,' ',$editor-name/tei:persName/tei:surname)
    let $sort-name :=
        for $editor-name in $editors//tei:person[@xml:id = $editor] return $editor-name/tei:persName/tei:surname
    order by $sort-name
    return
        if($editor != '') then 
            if(normalize-space($name) != '') then 
            <li>{normalize-space($name)}</li>
            else ''
        else ''  
};