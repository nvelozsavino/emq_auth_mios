PROJECT = emqttd_mios_plugin
PROJECT_DESCRIPTION = emqttd Authentication/ACL for MiOS
PROJECT_VERSION = 2.0

DEPS = jiffy emqttd

dep_emqttd = git https://github.com/emqtt/emqttd emq20
dep_jiffy = git https://github.com/davisp/jiffy.git master

ERLC_OPTS += +'{parse_transform, lager_transform}'

COVER = true

include erlang.mk

app:: rebar.config
