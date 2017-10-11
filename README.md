# log-muter

log-muter is a simple Sinatra webhook app (designed to be deployed to Heroku) that can auto-mute systems that are sending too many logs to Papertrail. This can help prevent [log floods](https://help.papertrailapp.com/kb/how-it-works/log-rate-notifications/) in a more fine-grained way.

## Setup

The app needs a Papertrail API key to make requests to the Papertrail account - set this in the PAPERTRAIL_API_KEY env variable.

A desirable log velocity will vary depending on the account. Setting a custom velocity threshold using MAX_VELOCITY is recommended. It's also possible to set the number of sequential alert invocations exceeding the threshold (SUSTAINED_DURATION) before the system is muted. For example, if this is set to 10 and the alert runs every minute (see below), the system must be rogue for 10 minutes before being muted.

## Account Setup

First, add a [log filter](https://help.papertrailapp.com/kb/how-it-works/log-filtering/) on the desired log destination for `-muted`. If this filter is not in place, the hook will have no effect.

Once deployed, the app can be added as a [count-only webhook alert](https://help.papertrailapp.com/kb/how-it-works/web-hooks/#count-only-webhooks) to any search that would indicate a problematic log velocity on 1-100 systems. If the webhook is not set to send counts, the app will return a 400.

It's meant to run every minute, but that's not required. Keep in mind that if it doesn't run every minute, the settings for MAX_VELOCITY and SUSTAINED_DURATION should reflect that. 

# How it works

This app is a bit of a hack. When it detects a sustained log spike, it changes the name of the system via the API to include `-muted`. From setup, there's already a log filter in place that filters messages containing `-muted`, so once the system name is updated, logs from it are effectively suppressed. (Past logs will also show the revised system name, for as long as it sticks around. This is useful, since it means it's easy to see when a system has been auto-muted.)

## Note

System auto-muting is a bit dangerous. It preserves the usability of the account at the expense of not collecting logs when a system is barfing. It might be worthwhile to set up this app with its own Papertrail alerts that let you know when a system is muted. If it's deployed to Heroku, attaching the Papertrail add-on means the logs can be checked for the message that indicates a system was muted and then send a notification. It's a little meta but it works.

# Limits

In addition to requiring a count-only webhook, the app doesn't do anything if there are counts in the payload for more than 100 systems. Try a per-group or host-specific search if there are too many systems being included. If you have a good idea of how to not need a limit to prevent overloading/taking too long, please submit a PR. :)

The app doesn't unmute systems. It would be possible to write a different route to handle that (and maybe hook it up to an [inactivity alert](https://help.papertrailapp.com/kb/how-it-works/alerts/#inactivity-alerts)), but: 

1. In an ideal worldd, this won't go off very often.
2. It'll probably involve some manual work to fix. 

Adding "update the system name back to normal after it's sorted" to the manual to-do list should probably work fine. Feel free to submit a PR if that turns out not to be true.
