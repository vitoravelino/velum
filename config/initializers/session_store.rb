# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  key:    "_velum_session",
  secure: !Rails.env.test?
