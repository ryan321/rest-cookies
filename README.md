# rest-cookies
Use cookies with MarkLogic REST API. 

## Why?
The MarkLogic REST API uses Basic Authentication. This can be a problem for middleware servers that maintain a session with the end user because the username and password for the user must be saved in a middleware session in order to use Basic Authentication with the MarkLogic REST API. If middleware sessions are persisted to the filesystem or in a database, then your users' passwords are saved in clear text. So rather than using Basic Auth that is sent with each request from middleware to the MarkLogic REST API, a MarkLogic server session can be created and a cookie returned that the middleware server can use instead of saving the username and password. Then this MarkLogic session ID can be persisted in the middleware session and no passwords are saved in clear text anywhere.

## How does it work?
- A custom login module (page) logs a user in
- A custom logout module (page) logs a user out
- A custom rewriter routes requests to the custom login and logout modules, and routes all other requests to the REST API but it first calls custom code to check for a custom cookie and attempts to log the user in using the cookie session ID
- Custom session code adds a cookie to the response after successful log in and writes a session xml doc to a configurable session database.
- When a request comes in and the custom session cookie is found, the session code looks up the corresponding session for the cookie and if a session xml doc is found and is still valid, then xdmp:login in called and the resulting REST API invocation happens under the logged in user

## Why use a custom session database?
MarkLogic already supports cookies and sessions but there are two drawbacks:
- Sessions are particular to an e-node. If you have multiple e-nodes, you would have to use a router that can use "sticky sessions" to send requests to the exact same e-node every time. That is not an optimal approach for load balancing, and if the e-node goes down, so does the session.
- Sessions are only in memory. If the MarkLogic server is restarted, then all sessions are lost. 

So the solution is to persist sessions in the database, which makes them available to all e-nodes and d-nodes (so any node can service the incoming request from any user), and the sessions are durable (they survive a system restart or adding or removing nodes).

## Installation
This is intended to be used with [mlpm](https://github.com/joemfb/mlpm). After mlpm is installed, you can install rest-cookies by adding the following dependency in mlpm.json in your project:
```
"dependencies": { 
  "rest-cookies": "*" 
} 
```
then run `mlpm install` from your project root. This will bring all the code files and put them under the `mlpm_modules` dir of your project.

## Configuration
The easiest way to configure your application to use rest-cookies is to use [Roxy](https://github.com/marklogic/roxy) in your project. There are sample files in the rest-cookies project that show what configuration properties need to be set.

### build.properties
These are the properties that must be set:
```
rest-port=8042 //any avilable port
rest-authentication-method=digestbasic
app-name-rest-modules=${app-name}-modules
sessions-db=${app-name}-sessions
authentication-method=application-level
app-type=rest
server-version=8
url-rewriter=/mlpm_modules/rest-cookies/rewriter.xqy
error-handler=/MarkLogic/rest-api/error-handler.xqy
rewrite-resolves-globally=true
session-amp-role=session-amp-role 
```

### ml-config.xml
```
<database>
    <database-name>@ml.sessions-db</database-name>
    <forests>
      <forest-id name="Sessions"/>
    </forests>
    <stemmed-searches>off</stemmed-searches>
    <word-searches>false</word-searches>
    <word-positions>false</word-positions>
    <fast-phrase-searches>false</fast-phrase-searches>
    <fast-reverse-searches>false</fast-reverse-searches>
    <fast-case-sensitive-searches>false</fast-case-sensitive-searches>
    <fast-diacritic-sensitive-searches>false</fast-diacritic-sensitive-searches>
    <fast-element-word-searches>false</fast-element-word-searches>
    <element-word-positions>false</element-word-positions>
    <fast-element-phrase-searches>false</fast-element-phrase-searches>
    <element-value-positions>false</element-value-positions>
    <attribute-value-positions>false</attribute-value-positions>
    <three-character-searches>false</three-character-searches>
    <three-character-word-positions>false</three-character-word-positions>
    <fast-element-character-searches>false</fast-element-character-searches>
    <trailing-wildcard-searches>false</trailing-wildcard-searches>
    <trailing-wildcard-word-positions>false</trailing-wildcard-word-positions>
    <fast-element-trailing-wildcard-searches>false</fast-element-trailing-wildcard-searches>
    <word-lexicons/>
    <two-character-searches>false</two-character-searches>
    <one-character-searches>false</one-character-searches>
    <uri-lexicon>true</uri-lexicon>
    <collection-lexicon>false</collection-lexicon>
    <directory-creation>automatic</directory-creation>
    <maintain-last-modified>false</maintain-last-modified>
</database>
...
<role>
  <role-name>@ml.session-amp-role</role-name>
  <description>Role that allows users to read and write sessions</description>
  <privileges>
    <privilege>
      <privilege-name>xdmp:eval</privilege-name>
    </privilege>
    <privilege>
      <privilege-name>xdmp:eval-in</privilege-name>
    </privilege>
    <privilege>
      <privilege-name>xdmp:login</privilege-name>
    </privilege>
    <privilege>
      <privilege-name>xdmp:add-response-header</privilege-name>
    </privilege>
    <privilege>
      <privilege-name>sessions-uri</privilege-name>
    </privilege>
  </privileges>
</role>
...
<amp>
  <namespace>http://marklogic.com/sessions</namespace>
  <local-name>login-if-ml-session</local-name>
  <doc-uri>/mlpm_modules/rest-cookies/sessions.xqy</doc-uri>
  <db-name>@ml.app-modules-db</db-name>
  <role-name>@ml.session-amp-role</role-name>
</amp>
<amp>
  <namespace>http://marklogic.com/sessions</namespace>
  <local-name>logout</local-name>
  <doc-uri>/mlpm_modules/rest-cookies/sessions.xqy</doc-uri>
  <db-name>@ml.app-modules-db</db-name>
  <role-name>@ml.session-amp-role</role-name>
</amp>
<amp>
  <namespace>http://marklogic.com/sessions</namespace>
  <local-name>create-session</local-name>
  <doc-uri>/mlpm_modules/rest-cookies/sessions.xqy</doc-uri>
  <db-name>@ml.app-modules-db</db-name>
  <role-name>@ml.session-amp-role</role-name>
</amp>
...
<privilege>
  <privilege-name>sessions-uri</privilege-name>
  <action>/sessions/</action>
  <kind>uri</kind>
</privilege>
```
Refer to the sample ml-config.xml file in the rest-cookies project.

### src/app/config/config.xqy
This file is used by roxy to dynamically replace tokens in the file with values specified in build.properties. If you don't have this file, you can create it. Refer to the sample file in the rest-cookies project.

Properties that must exist:
```
declare variable $SESSIONS-DB := "@ml.sessions-db";
declare variable $SESSION-AMP-ROLE := "@ml.session-amp-role";
```
