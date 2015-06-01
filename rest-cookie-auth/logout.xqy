import module namespace sessions = "rest-cookies/sessions" at "/sessions.xqy";

let $log-in := sessions:login-if-ml-session()
return sessions:logout()