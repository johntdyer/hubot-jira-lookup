#   Jira lookup when issues are heard
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JIRA_LOOKUP_USERNAME
#   HUBOT_JIRA_LOOKUP_PASSWORD
#   HUBOT_JIRA_LOOKUP_REPEAT_TIMEOUT
#   HUBOT_JIRA_LOOKUP_URL
#   HUBOT_JIRA_PROJECT_PATTERN
#
# Commands:
#   None
#
# Author:
#   Matthew Finlayson <matthew.finlayson@jivesoftware.com> (http://www.jivesoftware.com)
#   Benjamin Sherman  <benjamin@jivesoftware.com> (http://www.jivesoftware.com)
#   John Dyer  <johntdyer@gmail.com>

Util = require "util"

# Default timeout
expireTime = process.env.HUBOT_JIRA_LOOKUP_REPEAT_TIMEOUT || 3600000

#  JIRA project pattern
projectPattern = process.env.HUBOT_JIRA_PROJECT_PATTERN || /((PRISM|TROPO|ADMIN|OPS|DT|SUP)-\d{2,})\b/i

module.exports = (robot) ->

  check_message = (issue,chan) ->
    console.log "check_message #{issue}, #{chan}"
    channel = chan.replace(/\W/g, "");
    jira_issue = robot.brain.data.jira[channel+issue.replace(/\W/g, "")]

    if !jira_issue
      set_cache(issue,chan)
      return true
    else
      check_expiration(issue, chan)

  check_expiration = (issue,chan) ->
    console.log "check_expiration #{issue}, #{chan}"
    key = "#{chan.replace(/\W/g, "")}#{issue.replace(/\W/g, "")}"
    ticketData = robot.brain.data.jira[key]
    timeNow = Date.now()
    lastMessageTime =  ticketData.date
    lastMessageDuration = timeNow - lastMessageTime

    msg = ""
    if lastMessageDuration > expireTime
      # Delete old message
      key = "#{channel}#{issue.replace(/\W/g, "")}"
      delete robot.brain.data.jira[key]
      # Create new cache instance
      set_cache(issue,chan)
      msg = "Silence timeout has expired"
      return true
    else
      msg = "Silence timeout has not expired"
      false

    console.log "[JIRA] #{msg} for issue #{ticketData.ticket}@#{chan}- Last post was #{lastMessageDuration} milliseconds ago, silence expirationTime is #{expireTime} "

  set_cache = (issue,chan) ->
    console.log "set_cache #{issue}, #{chan}"
    channel = chan.replace(/\W/g, "");
    key = "#{channel}#{issue.replace(/\W/g, "")}"
    i = {}
    i.ticket = issue
    i.date = Date.now()
    i.channel = channel
    robot.brain.data.jira[key] = i
    console.log "[JIRA] issue #{issue}@#{channel} has been saved to cache"
    true


  if !robot.brain.data.jira
    console.log "[JIRA] Brain key is empty creating empty hash"
    robot.brain.data.jira = {}
  else

  robot.hear /((PRISM|TROPO|ADMIN|OPS|DT|SUP)-\d{2,})\b/i, (msg) ->

    clean_chan_name = msg.message.room.replace(/\W/g, "")
    issue = msg.match[1]

    #console.log "[JIRA] Heard issue #{issue} in #{msg.message.room} - [ Sanitized: #{clean_chan_name} ]"

    robot_should_talk = false

    # If the issue doesnt exist in brain we need to create it
    robot_should_talk = check_message(issue, msg.message.room)

    if robot_should_talk
      #console.log "msg.match: #{Util.inspect(msg.match)}"
      user = process.env.HUBOT_JIRA_LOOKUP_USERNAME
      pass = process.env.HUBOT_JIRA_LOOKUP_PASSWORD
      url = process.env.HUBOT_JIRA_LOOKUP_URL
      auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64');
      robot.http("#{url}/rest/api/latest/issue/#{issue}")
        .headers(Authorization: auth, Accept: 'application/json')
        .get() (err, res, body) ->
          try
            json = JSON.parse(body)
            json_summary = ""
            if json.fields.summary
                unless json.fields.summary is null or json.fields.summary.nil? or json.fields.summary.empty?
                    json_summary = json.fields.summary
            json_description = ""
            if json.fields.description
                json_description = "\n Description: "
                unless json.fields.description is null or json.fields.description.nil? or json.fields.description.empty?
                    desc_array = json.fields.description.split("\n")
                    for item in desc_array[0..2]
                        json_description += item
            json_assignee = ""
            if json.fields.assignee
                json_assignee = "Assignee: "
                unless json.fields.assignee is null or json.fields.assignee.nil? or json.fields.assignee.empty?
                    unless json.fields.assignee.name.nil? or json.fields.assignee.name.empty?
                        json_assignee += json.fields.assignee.name
            json_status = ""
            if json.fields.status
                json_status = "Status: "
                unless json.fields.status is null or json.fields.status.nil? or json.fields.status.empty?
                    unless json.fields.status.name.nil? or json.fields.status.name.empty?
                        json_status += json.fields.status.name
            #msg.send "Issue:       #{json.key}: #{json_summary}#{json_description}#{json_assignee}#{json_status}\nLink:        #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}\n"

            msg.send "#{json.key}: #{json_summary} - [ #{json_assignee}, #{json_status}, Link: #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key} ]"
          catch error
            console.error "[JIRA] error -> #{error}"
            msg.send "*sinister laugh*"

