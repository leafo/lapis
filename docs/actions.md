
## Request Object

As we've already seen the request object contains instance variables for all of
the request parameters in `@params`. There are a few other properties as well.

* `@req` -- raw request table (generated from `ngx` state)
* `@res` -- raw response table (used to update `ngx` state)
* `@app` -- the instance of the application
* `@cookies` -- the table of cookies, can be assigned to set new cookies. Only
  supports strings as values
* `@session` -- signed session table. Can store values of any
  type that can be JSON encoded. Is backed by cookies
* `@options` -- set of options that controls how the request is rendered to Nginx
* `@buffer` -- the output buffer
* `@route_name` -- the name of the route that matched the request if it has one

### @req

The raw request table `@req` wraps some of the ngx functions. Here is a list of utility functions available

 * `@req.headers` -- Request headers table
 * `@req.parsed_url` -- Request parsed url.. A table with scheme, path, host, port and query.
 * `@req.params_post` -- Request POST parameters table
 * `@req.params_get` -- Request GET parameters table


When an action is executed the `write` method (described below) is called with
the return values.

### Request Options

Whenever a table is written, the key/value pairs (when the key is a string) are
copied into `@options`. For example, in this action the `render` and `status`
properties are copied.

```moon
"/": => render: "error", status: 404
```

After the action is finished, the options help determine what is sent to the
browser.

Here is the list of options that can be written

* `status` -- sets HTTP status code (eg. 200, 404, 500, ...)
* `render` -- causes a view to be rendered with the request. If the value is
  `true` then the name of the route is used as the view name. Otherwise the value
  must be a string or a view class.
* `content_type` -- sets the `Content-type` header
* `json` -- causes the request to return the JSON encoded value of the
  property. The content type is set to `application/json` as well.
* `layout` -- changes the layout from the default defined by the application
* `redirect_to` -- sets status to 302 and sets `Location` header to value.
  Supports both relative and absolute URLs. (Combine with `status` to perform
  301 redirect)


When rendering JSON make sure to use the `json` render option. It will
automatically set the correct content type and disable the layout:

```moon
class extends lapis.Application
  "/hello": =>
    json: { hello: "world!" }
```

### Cookies

The `@cookies` table in the request lets you read and write cookies. If you try
to iterate over the table to print the cookies you might notice it's empty:

```moon
"/": =>
  for k,v in pairs(@cookies)
    print k,v
```

The existing cookies are stored in the `__index` of the metatable. This is done
so we can when tell what cookies have been assigned to during the action
because they will be directly in the `@cookies` table.

Thus, to set a cookie we just need to assign into the `@cookies` table:

```moon
"/": =>
  @cookies.foo = "bar"
```

### Session

The `@session` is a more advanced way to persist data over requests. The
content of the session is serialized to JSON and stored in store in a specially
named cookie. The serialized cookie is also signed with you application secret
so it can't be tampered with. Because it's serialized with JSON you can store
nested tables and other primitive values.

The session can be set and read the same way as cookies:

```moon
"/": =>
  unless @session.current_user
    @session.current_user = "leaf"
```

By default the session is stored in a cookie called `lapis_session`. You can
overwrite the name of the session using the `session_name` [configuration
variable](#configuration-and-environments). Sessions are signed with your
application secret, which is stored in the configuration value `secret`. It is
highly recommended to change this from the default.

```moon
import config from require "lapis.config"

config "development", ->
  session_name "my_app_session"
  secret "this is my secret string 123456"
```

### Methods

####  `write(things...)`

Writes all of the arguments. A different actions is done depending on the type
of each argument.

* `string` -- String is appended to output buffer
* `function` (or callable table) -- Function is called with the output buffer,
  result is recursively passed to `write`
* `table` -- key/value pairs are assigned into `@options`, all other values are
  recursively passed to `write`


#### `url_for(name_or_obj, params)`

Generates a URL for `name_or_obj`.

If `name_or_obj` is a string, then the route of that name is looked up and
filled using the values in params.

For example:

```moon
[user_data: "/data/:user_id/:data_field"]: =>

"/": =>
  -- returns: /data/123/height
  @url_for "user_data", user_id: 123, data_field: "height"
```

If `name_or_obj` is a table, then the `url_params` method is called on the
object. The arguments passed to `url_params` are the request, followed by all
the remaining arguments passed to `url_for`. The result of `url_params` is used
to call `url_for` again.

The values of params are inserted literally into the URL if they are strings.
If the value is a table then the `url_key` method is called and the result is
used as the URL value.

For example, consider a `Users` model and generating a URL for it:

```moon
class Users extends Model
  url_key: (route_name) => @id
```


#### `build_url(path, [options])`

Builds an absolute URL for the path. The current request's URI is used to build
the URL.

For example, if we are running our server on `localhost:8080`:

```moon
@build_url! --> http://localhost:8080
@build_url "hello" --> http://localhost:8080/hello

@build_url "world", host: "leafo.net", port: 2000 --> http://leafo.net:2000/world
```
