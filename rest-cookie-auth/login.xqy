import module namespace security = "security" at "/services/security.xqy";
import module namespace sessions = "http://marklogic.com/sessions"
    at "/sessions.xqy";

let $username := xdmp:get-request-field("username")
let $password := xdmp:get-request-field("password")

let $authed :=
  try {
    xdmp:login(security:get-system-username($username), $password)
  }
  catch($e) {
    fn:false()
  }

let $_ :=
  if ($authed)
  then sessions:create-session(xdmp:get-current-user())
  else ()

return "Logged in? "||$authed
