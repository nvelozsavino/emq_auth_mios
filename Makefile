PROJECT = emqttd_mios_plugin
PROJECT_DESCRIPTION = emqttd Authentication/ACL for MiOS
PROJECT_VERSION = 2.0

DEPS = gen_conf emqttd

dep_emqttd = git https://github.com/emqtt/emqttd emq20
dep_gen_conf = git https://github.com/emqtt/gen_conf master

ERLC_OPTS += +'{parse_transform, lager_transform}'

COVER = true

include erlang.mk

app:: rebar.config
