Genom
=====

** TODO: Add description **

otp - sup

otp - app, supervise of supervisors)

in config.exs add address of git where is config-to-use)) Clone / update it in init of app

config:
ip_addreses / ports of other supervisors
some info about this supervisor / program

internal_port(cowboy) <----> supervisors_in_this_host(..)
|
|
|
gen_server1() --> cache() <---> view(), view on cowboy + bullet + angular + bootstrap. etc
|
|
|
external_port(cowboy) <---> supervisors_in_other_hosts(...)


on some timeout after last connection do ping-pong query
or queries contain some info about states etc

gen_server(host leader) sends to other hosts list of info about itself and other apps in this host
if can's connect to host leader - became host leader itself

#
# EXPOKER - TODO fix generating of next expected card in copies of apps when reading up-to-date state
#