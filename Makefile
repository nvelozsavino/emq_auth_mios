PROJECT = emqttd_mios_plugin
PROJECT_DESCRIPTION = emqttd Authentication/ACL for MiOS
PROJECT_VERSION = 2.0

DEPS = emqttd

dep_emqttd = git https://github.com/emqtt/emqttd emq20

ERLC_OPTS += +'{parse_transform, lager_transform}'

COVER = true

include erlang.mk

app:: rebar.config
