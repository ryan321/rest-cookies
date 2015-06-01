import module namespace sessions = "http://marklogic.com/sessions"
    at "/sessions.xqy";

let $log-in := sessions:login-if-ml-session()
return sessions:logout()