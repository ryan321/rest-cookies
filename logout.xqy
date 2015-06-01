import module namespace sessions = "rest-cookies/sessions" at "/mlpm_modules/rest-cookies/sessions.xqy";

let $log-in := sessions:login-if-ml-session()
return sessions:logout()