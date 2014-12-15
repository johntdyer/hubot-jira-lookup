# Description:
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

  is_expired = (issue) ->
    ticketData = robot.brain.data.jira[issue]
    timeNow = Date.now()
    lastMessageTime =  ticketData.date
    lastMessageDuration = timeNow - lastMessageTime

    expired = lastMessageDuration > expireTime
    msg = ""
    if expired
      # Delete old message
      delete robot.brain.data.jira[issue]
      # Create new cache instance
      set_cache(issue)
      msg = "silence timeout has expired"
    else
      msg = "silence timeout has not expired"

    console.log "#{msg} for issue #{ticketData.ticket} - Last post was #{lastMessageDuration} milliseconds ago, silence expirationTime is #{expireTime} "
    return expired

  set_cache = (issue) ->
    i = {}
    i.ticket = issue
    i.date = Date.now()
    robot.brain.data.jira[issue] = i
    console.log "issue #{issue} has been saved to cache"
    true


  if !robot.brain.data.jira
    console.log "Brain key is empty creating empty hash"
    robot.brain.data.jira = {}
  else

  robot.respond projectPattern, (msg) ->
    issue = msg.match[1]

    jira_issue = robot.brain.data.jira[issue]

    robot_should_talk = false

    # If the issue doesnt exist in brain we need to create it
    robot_should_talk = if !jira_issue
      set_cache(issue)
    else
      is_expired(issue)


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
                json_assignee = "\nAssignee:    "
                unless json.fields.assignee is null or json.fields.assignee.nil? or json.fields.assignee.empty?
                    unless json.fields.assignee.name.nil? or json.fields.assignee.name.empty?
                        json_assignee += json.fields.assignee.name
            json_status = ""
            if json.fields.status
                json_status = "\nStatus:      "
                unless json.fields.status is null or json.fields.status.nil? or json.fields.status.empty?
                    unless json.fields.status.name.nil? or json.fields.status.name.empty?
                        json_status += json.fields.status.name
            msg.send "Issue:       #{json.key}: #{json_summary}#{json_description}#{json_assignee}#{json_status}\nLink:        #{process.env.HUBOT_JIRA_LOOKUP_URL}/browse/#{json.key}\n"
          catch error
            console.error "error -> #{error}"
            msg.send "*sinister laugh*"

