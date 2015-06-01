xquery version "1.0-ml";

(: Copyright 2011-2014 MarkLogic Corporation.  All Rights Reserved. :)

import module namespace rest = "http://marklogic.com/appservices/rest"
    at "/MarkLogic/appservices/utils/rest.xqy";

import module namespace conf = "http://marklogic.com/rest-api/endpoints/config"
    at "/MarkLogic/rest-api/endpoints/config.xqy";

import module namespace sessions = "rest-cookies/sessions"
    at "/sessions.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";
declare option xdmp:mapping "false";

let $uri  := xdmp:get-request-url()
return (
    if (xdmp:get-request-path() = ("/rest-cookie-auth/login.xqy", "/rest-cookie-auth/logout.xqy"))
    then $uri
    else
        let $_ := sessions:login-if-ml-session()
        return
          conf:rewrite(xdmp:get-request-method(), $uri, xdmp:get-request-path()),
          $uri
          )[1]
