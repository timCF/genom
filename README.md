Genom
=====

Is lightweight otp - application which help you to see states of your other otp-applications in network.

Just add genom to your app list, configure config.exs file like this :

```
config :genom, app: :my_otp_app, port: 8998, comment: "my otp application"
```
(note: this port must be opened!)

If you want to send info about state of your application to other hosts, add genom.yml to priv dir of application.  This file must contain something like this:

```
hosts:
 - host: "192.168.59.103"
   port: 8998
   comment: "office centos VM"
 - host: "192.168.59.3"
   port: 8998
   comment: "office MAC"
```

If you want add some special values to state for observing in the web, you can write somethere in your application

```
Genom.add_info("Some info about my state", :some_key)
```

And now observe info about your hosts / applications / modules in localhost:8998