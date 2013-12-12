# Description:
#   Build a markov model based on everything that Hubot sees. Construct markov
#   chains based on its accumulated history on demand, to produce plausible-
#   sounding and occasionally hilarious nonsense.
#
#   While this is written to support any order of markov model, extensive
#   experimentation has shown that order 1 produces the most funny. Higher-
#   order models occupy a *lot* more storage space and frequently produce
#   exact quotes.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_MARKOV_PLY - Order of the markov model to build. Default: 1
#   HUBOT_MARKOV_MAX - Maximum number of tokens in a generated chain. Default: 50
#   HUBOT_MARKOV_MIN_TRAIN - Mininum number of tokens to train on. Default: 1
#
# Commands:
#   hubot markov <seed> - Generate a markov chain, optionally seeded with the provided phrase.
#
# Author:
#   smashwilson

Url = require 'url'
Redis = require 'redis'

MarkovModel = require './model'
RedisStorage = require './redis-storage'

module.exports = (robot) ->

  # Configure redis the same way that redis-brain does.
  info = Url.parse process.env.REDISTOGO_URL or
    process.env.REDISCLOUD_URL or
    process.env.BOXEN_REDIS_URL or
    'redis://localhost:6379'
  client = Redis.createClient(info.port, info.hostname)
  storage = new RedisStorage(client)

  # Read markov-specific configuration from the environment.
  ply = process.env.HUBOT_MARKOV_PLY or 1
  max = process.env.HUBOT_MARKOV_MAX or 50
  min_train = process.env.HUBOT_MARKOV_MIN_TRAIN or 1

  model = new MarkovModel(storage, ply, min_train)

  # The robot hears ALL. You cannot run.
  robot.hear /.+$/, (msg) ->
    # Don't learn from commands sent to the bot directly.
    name = robot.name.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
    if robot.alias
      alias = robot.alias.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')
      r = new RegExp("^[@]?(?:#{alias}[:,]?|#{name}[:,]?)", "i")
    else
      r = new RegExp("^[@]?#{name}[:,]?", "i")
    return if r.test msg.match[0]

    model.learn msg.match[0]

  # Generate markov chains on demand, optionally seeded by some initial state.
  robot.respond /markov(\s+(.+))?$/i, (msg) ->
    model.generate msg.match[2] or '', max, (text) =>
      msg.send text
