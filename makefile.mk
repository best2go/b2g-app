#!/usr/bin/make

# The five internal macros are:
# $@ - The $@ shall evaluate to the full target name of the current target, or the archive filename part of a library
#      archive target. It shall be evaluated for both target and inference rules. For example, in the .c.a inference
#      rule, $@ represents the out-of-date .a file to be built. Similarly, in a makefile target rule to build lib.a from
#      file.c, $@ represents the out-of-date lib.a.
# $% - The $% macro shall be evaluated only when the current target is an archive library member of the form
#      library(member.o). In these cases, $@ shall evaluate to library and $% shall evaluate to member.o. The $% macro
#      shall be evaluated for both target and inference rules. For example, in a makefile target rule to build
#      lib.a(file.o), $% represents file.o, as opposed to $@, which represents lib.a.
# $? - The $? macro shall evaluate to the list of prerequisites that are newer than the current target. It shall be
#      evaluated for both target and inference rules. For example, in a makefile target rule to build prog from file1.o,
#      file2.o, and file3.o, and where prog is not out-of-date with respect to file1.o, but is out-of-date with respect
#      to file2.o and file3.o, $? represents file2.o and file3.o.
# $< - In an inference rule, the $< macro shall evaluate to the filename whose existence allowed the inference rule to
#      be chosen for the target. In the .DEFAULT rule, the $< macro shall evaluate to the current target name.
#      The meaning of the $< macro shall be otherwise unspecified.
#      For example, in the .c.a inference rule, $< represents the prerequisite .c file.
# $* - The $* macro shall evaluate to the current target name with its suffix deleted. It shall be evaluated at least
#      for inference rules. For example, in the .c.a inference rule, $*.o represents the out-of-date .o file that
#      corresponds to the prerequisite .c file.
#
# For the target library(member.o) and the s2.a rule, the internal macros shall be defined as:
# $< - member.s2
# $* - member
# $@ - library
# $? - member.s2
# $% - member.o

# https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
$(DEBUG).SILENT: ;       # no need for @, DEBUG=yes make ... disable silence
.EXPORT_ALL_VARIABLES: ; # send all vars to shell
.NOTPARALLEL: ;          # wait for target to finish
.ONESHELL: ;             # when a target is built all lines of the recipe will be given to a single invocation
.SUFFIXES: ;             # skip suffix discovery
.DEFAULT_GOAL = .help    # Run make help by default
#.IGNORE: ;               # Ignore error codes returned by invoked commands

# Emits a warning if you are referring to Make variables that don’t exist.
#MAKEFLAGS += --warn-undefined-variables

# Removes a large number of built-in rules. Remove "magic" and only do
#    what we tell Make to do.
MAKEFLAGS += --no-builtin-rules

# skip discovery
makefile: ;              # skip prerequisite discovery
makefile.%: ;            # skip prerequisite discovery
.env.docker.%: ;         # skip .env discovery

-include .env.docker.dist
-include .env.docker.local

#regexp_true := ^\s*(true|1|on|TRUE|ON)\s*$
SWITCH_ON  = ON on TRUE true 1
SWITCH_OFF = OFF off FALSE false 0

DOCKERFILE ?= dockerfile
DOCKER := docker $(DOCKER_ARGS)
DC = docker-compose $(DC_ARGS) $(DOCKER_COMPOSE_FILES)
DC_EXEC = $(DC) exec $(DC_EXEC_ARGS)
DC_ARGS ?=
DOCKER_ARGS ?=
DC_EXEC_ARGS ?=
CMD_ARGS ?=

REPOSITORY_ID ?= local/$(APP)
COMMIT_ID ?= $(shell git rev-parse --short=7 HEAD)

DOCKER_COMPOSE_FILES :=
DOCKER_IMAGES :=

COMPOSER = $(DC_EXEC) --env APP_DEBUG=false --env APP_ENV=prod $(PHP) composer
CONSOLE  = $(DC_EXEC) --env APP_DEBUG=false --env APP_ENV=prod $(PHP) php -d memory_limit=-1 -f bin/console --
XCONSOLE = $(DC_EXEC) --env APP_DEBUG=true  --env APP_ENV=dev  $(PHP) php -d memory_limit=-1 -f bin/console --
NGINX    = $(DC_EXEC) nginx nginx
COMMAND ?=
COMMAND_ARGS ?=

ifndef APP_TAG
	APP_TAG := $(if $(COMMIT_ID),$(COMMIT_ID),$(shell git rev-parse --short=7 HEAD))
endif

ifndef APP_OTP
	APP_OTP := $(shell openssl rand -hex 8 || echo $(APP_TAG))
endif

MAKE_UP_AND_RUN_DEPENDENCIES := build up

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_PHP)),)
$(eval ".PHONY: php.so cache.php.so")
	DOCKER_COMPOSE_FILES += -f docker-compose.php.yml
    DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.php.override.yml))
	DOCKER_IMAGES += php.so
	DOCKER_BUILD_ARG_PHP ?= \
		--build-arg APP_OTP="$(APP_OTP)" \
        --build-arg APP_TAG="$(APP_TAG)" \
        --build-arg BASE_PHP="$(BASE_PHP)" \
        --label com.$(APP).$(call lowercase, $*).php="$(BASE_PHP)" \
        --label com.$(APP).$(call lowercase, $*).otp="$(APP_OTP)" \
        --label com.$(APP).$(call lowercase, $*).tag="$(APP_TAG)"
endif

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_XPHP)),)
$(eval ".PHONY: xphp.so cache.xphp.so")
    DOCKER_COMPOSE_FILES += -f docker-compose.xphp.yml
    DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.xphp.override.yml))
    DOCKER_IMAGES += xphp.so
	DOCKER_BUILD_ARG_XPHP ?= \
		--build-arg APP_OTP="$(APP_OTP)" \
        --build-arg APP_TAG="$(APP_TAG)" \
        --build-arg BASE_PHP=$(BASE_PHP) \
        --label com.$(APP).$(call lowercase, $*).php="$(BASE_PHP)" \
        --label com.$(APP).$(call lowercase, $*).otp="$(APP_OTP)" \
        --label com.$(APP).$(call lowercase, $*).tag="$(APP_TAG)"
endif

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_NGINX)),)
$(eval ".PHONY: nginx.so cache.nginx.so")
    DOCKER_COMPOSE_FILES += -f docker-compose.nginx.yml
    DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.nginx.override.yml))
    DOCKER_IMAGES += nginx.so
    DOCKER_BUILD_ARG_NGINX ?= \
    	--build-arg APP_OTP="$(APP_OTP)" \
        --label com.$(APP).$(call lowercase, $*).otp="$(APP_OTP)"
endif

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_DB)),)
    DOCKER_COMPOSE_FILES += -f docker-compose.db.yml
    DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.db.override.yml))
endif

ifneq ($(wildcard docker-compose.override.yml),)
    DOCKER_COMPOSE_FILES += -f docker-compose.override.yml
endif

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_MUTAGEN)),)
    DOCKER_COMPOSE_FILES += -f docker-compose.mutagen.yml
    DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.mutagen.override.yml))
	MAKE_UP_AND_RUN_DEPENDENCIES := mutagen.terminate mutagen.start
endif

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_NGROK)),)
    DOCKER_COMPOSE_FILES += -f docker-compose.ngrok.yml
	DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.ngrok.override.yml))
endif

ifneq ($(filter $(SWITCH_ON), $(DOCKER_INCLUDE_BLACKFIRE)),)
    DOCKER_COMPOSE_FILES += -f docker-compose.blackfire.yml
	DOCKER_COMPOSE_FILES += $(addprefix -f ,$(wildcard docker-compose.blackfire.override.yml))
endif

ifdef DOCKER_COMPOSE_ADDONS
    DOCKER_COMPOSE_FILES += $(DOCKER_COMPOSE_ADDONS)
endif

ifdef DOCKER_IMAGES_ADDONS
    DOCKER_IMAGES += ${DOCKER_IMAGES_ADDONS}
endif

DOCKER_PULL := $(DOCKER) pull
ifeq ($(REPOSITORY_ID),local/$(APP))
	DOCKER_PULL := @echo "skip... docker pull"
endif

PHP := $(or \
	$(filter php, $(DOCKER_IMAGES:.so=)),  \
	$(filter xphp, $(DOCKER_IMAGES:.so=)), \
    $(error "I'm not aware of any PHP container!") \
)

XPHP := $(or \
	$(filter xphp, $(DOCKER_IMAGES:.so=)), \
	$(filter php, $(DOCKER_IMAGES:.so=)),  \
    $(error "I'm not aware of any xPHP container!") \
)

define lowercase
$(shell echo $(1) | tr '[:upper:]' '[:lower:]')
endef

define uppercase
$(shell echo $(1) | tr '[:lower:]' '[:upper:]')
endef

.PHONY: init
init: diagnose .init.ssl .init.dist .init.env.dist .readme ## init system

.PHONY: diagnose
diagnose: ## Diagnoses the system to identify common errors.
	$(if $(shell type tr),$(info tr: ok),$(error tr not found))
	$(if $(shell git --version),$(info git: ok),$(error git not found))
	$(if $(shell egrep --version),$(info egrep: ok),$(error egrep not found))
	$(if $(shell openssl version),$(info openssl: ok),$(warning openssl not found))
	$(if $(shell docker --version),$(info docker: ok),$(error docker not found))
	$(if $(shell docker-compose --version),$(info docker-compose: ok),$(error docker-compose not found))
	$(if $(shell egrep "^127.0.0.1\s+([^#]*\s)?$(APP)(\s.*|$$)" /etc/hosts),$(info /etc/hosts[$(APP)]: ok),$(warning /etc/hosts[$(APP)] missed))
	$(if $(shell egrep "^127.0.0.1\s+([^#]*\s)?$(APP).com(\s.*|$$)" /etc/hosts),$(info /etc/hosts[$(APP).com]: ok),$(warning /etc/hosts[$(APP).com] missed))
	$(if $(shell egrep "^127.0.0.1\s+([^#]*\s)?www.$(APP).com(\s.*|$$)" /etc/hosts),$(info /etc/hosts[www.$(APP).com]: ok),$(warning /etc/hosts[www.$(APP).com] missed))

.PHONY: .readme
.readme:
	$(warning >>> review all *.override.yml)
	$(warning >>> $(MAKE) config | Validate and view the Compose file.)
	$(warning >>> $(MAKE) .help  | List targets.)
	$(warning >>> $(MAKE) up-and-run)
	$(warning >>> ... (coffee))
	$(warning >>> curl --head --insecure http://127.0.0.1:8080/)
	$(warning >>> curl --head --insecure http://127.0.0.1:8080/?XDEBUG_SESSION=nick.lavrik)
	$(warning >>> $(MAKE) exec xphp php CMD_ARGS="-f bin/console doctrine:schema:validate")
	$(warning >>> echo "select * from syslog" | make mysql-ci CMD_ARGS="--table")

.PHONY: .init.ssl
.init.ssl:
	$(warning /** TODO: ssl provision */)

.PHONY: .init.env.dist
.init.env.dist: $(addprefix  .init., .env.docker.db.local.dist .env.docker.local.dist)

.PHONY: .init.dist
.init.dist: $(addprefix  .init., $(wildcard *.dist))

.init.%.dist:
	-cp -n $*.dist $*

.PHONY: info
info:
	@#echo "MAKEFILE_LIST = $(strip $(MAKEFILE_LIST))"
	@#echo "DOCKER_COMPOSE_FILES = $(strip $(DOCKER_COMPOSE_FILES))"
	@echo "BASE_PHP = '$(BASE_PHP)'"
	@echo "DOCKER_IMAGES = '$(DOCKER_IMAGES:.so=)'"
	@echo "COMMIT_ID = $(COMMIT_ID)"
	@echo "COMMAND = $(COMMAND) $(COMMAND_ARGS) $(CMD_ARGS)"
	@#echo "PHP = $(PHP)"
	@#echo "XPHP = $(XPHP)"
	@echo "APP_OTP = $(strip $(APP_OTP))"
	@echo "APP_TAG = $(strip $(APP_TAG))"
	@#echo "MYSQL_USER = $(MYSQL_USER)"


## dumb targets
.PHONY: ngrok
ngrok:
	@echo "ngrok command terminator."
	@true

.PHONY: php
php:
	@echo "php command terminator."
	@true

.PHONY: xphp
xphp:
	@echo "xphp command terminator."
	@true

.PHONY: bash
bash:
	@echo "bash command terminator."
	@true
