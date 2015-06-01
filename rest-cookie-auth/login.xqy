import module namespace sessions = "rest-cookies/sessions" at "/sessions.xqy";

let $username := xdmp:get-request-field("username")
let $password := xdmp:get-request-field("password")

let $authed :=
  try {
    xdmp:login($username, $password)
  }
  catch($e) {
    fn:false()
  }

let $_ :=
  if ($authed)
  then sessions:create-session(xdmp:get-current-user())
  else ()

return "Logged in? "||$authed
