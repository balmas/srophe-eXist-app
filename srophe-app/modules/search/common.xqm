xquery version "3.0";
(:~
 : Shared functions for search modules 
 :)
module namespace common="http://syriaca.org/common";
import module namespace global="http://syriaca.org/global" at "../lib/global.xqm";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~
 : Cleans search parameters to replace bad/undesirable data in strings
 : @param-string parameter string to be cleaned
 : NOTE to self: Need to handle ' in full text search, currently stripped before sent to ft:query() function
 :
:)
declare function common:clean-string($param-string){
replace(replace(replace($param-string, "(^|\W\*)|(^|\W\?)|[!@#$%^+=_]:", ""), '&amp;', '&amp;amp;'), '''', '&amp;apos;')
};

(:~
 : Strips english titles of non-sort characters as established by Syriaca.org
 : Used for sorting for browse and search modules
 : @param $titlestring 
 :)
declare function common:build-sort-string($titlestring as xs:string*) as xs:string* {
    replace(replace(replace(replace($titlestring,'^\s+',''),'^al-',''),'[‘ʻʿ]',''),'On ','')
};

(:~
 : Search options passed to ft:query functions
:)
declare function common:options(){
    <options>
        <default-operator>and</default-operator>
        <phrase-slop>1</phrase-slop>
        <leading-wildcard>no</leading-wildcard>
        <filter-rewrite>yes</filter-rewrite>
    </options>
};

(:
 : @depreciated
 : Uses eXistdb syntax to build complex search queries
:)
declare function common:build-query($param-string){
    <query>
        {
        if(starts-with($param-string,'"')) then 
         <query>
             <phrase slop="5">
                 {
                 for $term in tokenize($param-string,' ')
                 return
                     <term>{replace(common:clean-string($term),'"','')}</term>
                 }
             </phrase>
         </query>
        else 
            for $term in tokenize($param-string,' ')
            return 
                <term>{common:clean-string($term)}</term>
        }
    </query>
};

(:~
 : Function to cast dates strings from url to xs:date
 : Tests string length, may need something more sophisticated to test dates, 
 : or form validation via js before submit. 
 : @param $date passed to function from parent function
:)
declare function common:do-date($date){
let $date-format := if(string-length($date) eq 4) then concat(string($date),'-01-01')
                    else if(string-length($date) eq 5) then concat(string($date),'-01-01')
                    else if(string-length($date) eq 3) then concat('0',string($date),'-01-01')
                    else if(string-length($date) eq 2) then concat('00',string($date),'-01-01')
                    else if(string-length($date) eq 1) then concat('000',string($date),'-01-01')
                    else string($date)
let $final-date := xs:date($date-format) 
return $final-date
};

(:
 : Function to truncate description text after first 12 words
 : @param $string
:)
declare function common:truncate-string($str as xs:string*) as xs:string? {
let $string := string-join($str, ' ')
return 
    if(count(tokenize($string, '\W+')[. != '']) gt 12) then 
        let $last-words := tokenize($string, '\W+')[position() = 14]
        return concat(substring-before($string, $last-words),'...')
    else $string
};

(: 
 : Formats search and browse results 
 : Uses English and Syriac headwords if available, tei:teiHeader/tei:title if no headwords.
 : Should handle all data types, and eliminate the need for 
 : data type specific display functions eg: persons:saints-results-node()
 : @param $node search/browse hits should be either tei:person, tei:place, or tei:body
 : Used by search.xqm and browse.xqm
:)
declare function common:display-recs-short-view($node, $lang) as node()*{
let $ana := if($node/descendant-or-self::tei:person/@ana) then replace($node/descendant-or-self::tei:person/@ana,'#syriaca-','') else ()
let $type := if($node/descendant-or-self::tei:place/@type) then string($node/descendant-or-self::tei:place/@type) else ()
let $uri := 
        if($node//tei:idno[@type='URI'][starts-with(.,$global:base-uri)]) then
                string(replace($node//tei:idno[@type='URI'][starts-with(.,$global:base-uri)][1],'/tei',''))
        else string($node//tei:div[1]/@uri)
let $en-title := 
             if($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^en')][1]/child::*) then 
                 string-join($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^en')][1]/child::*/text(),' ')
             else if(string-join($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^en')][1]/text())) then 
                string-join($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^en')][1]/text(),' ')   
             else $node/ancestor::tei:TEI/descendant::tei:title[1]/text()       
let $syr-title := 
             if($node/descendant::*[@syriaca-tags='#syriaca-headword'][1]) then
                if($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^syr')][1]/child::*) then 
                 string-join($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^syr')][1]/child::*/text(),' ')
                else string-join($node/descendant::*[@syriaca-tags='#syriaca-headword'][matches(@xml:lang,'^syr')][1]/text(),' ')
             else 'NA' 
let $birth := if($ana) then $node/descendant::tei:birth else()
let $death := if($ana) then $node/descendant::tei:death else()
let $dates := concat(if($birth) then $birth/text() else(), if($birth and $death) then ' - ' else if($death) then 'd.' else(), if($death) then $death/text() else())    
let $desc :=
        if($node/descendant::*[starts-with(@xml:id,'abstract')]/descendant-or-self::text()) then
            common:truncate-string($node/descendant::*[starts-with(@xml:id,'abstract')]/descendant-or-self::text())
        else ()
return
    <p class="results-list">
       <a href="{replace($uri,$global:base-uri,$global:nav-base)}">
        {
        if($lang = 'syr') then
            (<span dir="rtl" lang="syr" xml:lang="syr">{$syr-title}</span>,' - ',
             <span dir="ltr" lang="en">{concat($en-title,
                if($type) then concat(' (',$type,')') else ())}
             </span>)
        else
        ($en-title,
          if($type) then concat('(',$type,')') else (),
            if($syr-title) then 
                if($syr-title = 'NA') then ()
                else (' - ', <span dir="rtl" lang="syr" xml:lang="syr">{$syr-title}</span>)
          else ' - [Syriac Not Available]')
          }   
       </a>
       {if($ana) then
            <span class="results-list-desc" dir="ltr" lang="en">{concat('(',$ana, if($dates) then ', ' else(), $dates ,')')}</span>
        else ()}
     <span class="results-list-desc" dir="ltr" lang="en">{concat($desc,' ')}</span>
     {
        if($ana) then 
            if($node/descendant-or-self::tei:person/tei:persName[not(@syriaca-tags='#syriaca-headword')]) then 
                <span class="results-list-desc" dir="ltr" lang="en">Names: 
                {
                    for $names in $node/descendant-or-self::tei:person/tei:persName[not(@syriaca-tags='#syriaca-headword')]
                    [not(starts-with(@xml:lang,'syr'))][not(starts-with(@xml:lang,'ar'))][not(@xml:lang ='en-xsrp1')]
                    return <span class="pers-label badge">{global:tei2html($names)}</span>
                }
                </span>
            else() 
        else()
        }
     <span class="results-list-desc"><span class="srp-label">URI: </span><a href="{replace($uri,$global:base-uri,$global:nav-base)}">{$uri}</a></span>
    </p>
};