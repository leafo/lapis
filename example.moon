
lapis = require "lapis"
csrf = require "lapis.csrf"

import Model from require "lapis.db.model"
import respond_to, capture_errors from require "lapis.application"

class Users extends Model
  url_params: =>
    "user", id: @id

class App extends lapis.Application
  -- Execute code before every action
  @before_filter =>
    @csrf_token = csrf.generate_token @

  [list_users: "/users"]: =>
    users = Users\select! -- `select` all the users

    -- Render HTML inline for simplicity
    @html ->
      ul ->
        for user in *users
          li ->
            a href: @url_for(user), user.name

  [user: "/profile/:id"]: =>
    user = Users\find id: @params.id
    return status: 404 unless user
    @html -> h2 user.name

  [new_user: "/user/new"]: respond_to {
    POST: capture_errors =>
      csrf.assert_token @
      Users\create name: @params.username
      redirect_to: @url_for "list_users"

    GET: =>
      @html ->
        form method: "POST", action: @url_for("new_user"), ->
          input type: "hidden", name: "csrf_token", value: @csrf_token
          input type: "text", name: "username"
  }
