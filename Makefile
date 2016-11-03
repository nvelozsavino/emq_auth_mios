PROJECT = emq_auth_mios
PROJECT_DESCRIPTION = EMQ Authentication/ACL for MiOS
PROJECT_VERSION = 2.0

BUILD_DEPS = jiffy emqttd
dep_emqttd = git https://github.com/emqtt/emqttd master
dep_jiffy = git https://github.com/davisp/jiffy.git master

TEST_DEPS = cuttlefish
dep_cuttlefish = git https://github.com/emqtt/cuttlefish

COVER = true

include erlang.mk

app:: rebar.config

app.config::
	cuttlefish -l info -e etc/ -c etc/emq_auth_mios.conf -i priv/emq_auth_mios.schema -d data
