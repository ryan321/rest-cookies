module namespace sessions = "rest-cookies/sessions";

import module namespace cookies = "http://parthcomp.com/cookies"
    at "/mlpm_modules/rest-cookies/cookies.xqy";
import module namespace config = "roxy/config"
    at "/app/config/config.xqy";

declare variable $COOKIE-NAME := "mlSessionId";

declare function create-session($username as xs:string) {
  let $session-id := xs:string(xdmp:random(9999999999999))

  let $expiration-dateTime := () (: fn:current-dateTime() + xs:dayTimeDuration('PT1H') :)

  let $_ := cookies:add-cookie($COOKIE-NAME, $session-id, $expiration-dateTime, (), "/", fn:false())

  let $expriation-attr :=
    if (fn:exists($expiration-dateTime))
    then attribute { 'expiration'} { $expiration-dateTime }
    else ()

  let $uri := "/sessions/"||$session-id||".xml"
  let $xml := <session id="{$session-id}" username="{$username}">{$expriation-attr}</session>

  let $s :=
      'xquery version "1.0-ml";
       declare variable $uri as xs:string external;
       declare variable $xml as element() external;
       xdmp:document-insert($uri, $xml)'
  return
    xdmp:eval(
      $s,
      (xs:QName("uri"), $uri, xs:QName("xml"), $xml),
      <options xmlns="xdmp:eval">
        <database>{xdmp:database($config:SESSIONS-DB)}</database>
      </options>
    )
};

declare private function get-session($session-id as xs:string) {
  let $s :=
      'xquery version "1.0-ml";
       declare variable $session-id as xs:string external;
       /session[@id = $session-id]'
  let $session :=
    xdmp:eval(
      $s,
      (xs:QName("session-id"), $session-id),
      <options xmlns="xdmp:eval">
        <database>{xdmp:database($config:SESSIONS-DB)}</database>
      </options>
    )

  return
    if ($session)
    then
      (:let $_ := xdmp:log("found session for session id: "||$session-id)
      let $_ := xdmp:log($session)
      return:)
        if (fn:not(fn:exists($session/expiration-dateTime)) or (fn:exists($session/expiration-dateTime) and $session/expiration-dateTime/xs:dateTime(.) gt fn:current-dateTime()))
        then $session
        else delete-session($session-id, xdmp:get-current-user())
    else ()
};

declare private function delete-session($session-id as xs:string, $username as xs:string) {
  let $s :=
      'xquery version "1.0-ml";
       declare variable $session-id as xs:string external;
       declare variable $username as xs:string external;
       let $session := /session[@id = $session-id]
       return
          if ($session/@username = $username)
          then $session/xdmp:document-delete(xdmp:node-uri(.))
          else ()'
  return
    xdmp:eval(
      $s,
      (xs:QName("session-id"), $session-id, xs:QName("username"), $username),
      <options xmlns="xdmp:eval">
        <database>{xdmp:database($config:SESSIONS-DB)}</database>
      </options>
    )
  (:let $_ := xdmp:log("found session to delete")
  let $_ := xdmp:log($session)
  let $_ := xdmp:log("session username: "||$session/@username)
  let $_ := xdmp:log("$username: "||$username):)

};

declare function login-if-ml-session() {
  let $_ := xdmp:log(xdmp:get-request-header("Cookie"))
  let $session-id := cookies:get-cookie($COOKIE-NAME)
  let $_ := xdmp:log("$session-id: "||$session-id)
  return
    if ($session-id)
    then
      let $session := get-session($session-id)
      return
        if (fn:exists($session))
        then
          let $_ := xdmp:log("logging in user: "||$session/@username/fn:string())
          return xdmp:login($session/@username)
        else ()
    else ()
};

declare function logout() {
  let $session-id := cookies:get-cookie($COOKIE-NAME)
  let $_ := xdmp:log("deleting session: "||$session-id)
  return
    if ($session-id)
    then delete-session($session-id, xdmp:get-current-user())
    else ()
};
