#!/usr/bin/make

include makefile.mk

UNAME := $(shell uname -s | tr '[:upper:]' '[:lower:]')

os: # darwin / linux
	@echo $(UNAME)

.PHONY: composer
composer:
	$(COMPOSER) $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: console
console: info
	$(XCONSOLE) $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: exec
exec: ## make exec ${SERVICE:-xphp} ${COMMAND:-bash} {ARGS...} ${CMD_ARGS}
	$(DC_EXEC) $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: prune
prune: ## remove dangling docker images and volume
	#docker images --all --quiet --filter 'dangling=true' | xargs --no-run-if-empty docker rmi
	#docker volume ls --quiet --filter 'dangling=true' | xargs --no-run-if-empty docker volume rm
	$(DOCKER) images --all --quiet --filter 'dangling=true' | xargs $(DOCKER) rmi || true
	$(DOCKER) volume ls --quiet --filter 'dangling=true' | xargs $(DOCKER) volume rm || true

.PHONY: cleanup ## remove old images
cleanup: $(addprefix cleanup.,$(DOCKER_IMAGES))

.PHONY: cleanup.%.so
cleanup.%.so:
	$(DOCKER) images $(REPOSITORY_ID) \
		--filter=before="$(REPOSITORY_ID):$(*)-$(APP_TAG)" \
		--format="{{.ID}}    {{.Repository}}:{{.Tag}}" \
	|| true
	$(DOCKER) images $(REPOSITORY_ID) \
		--filter=before="$(REPOSITORY_ID):$(*)-$(APP_TAG)" \
		--filter "dangling=true" \
		--quiet \
	| xargs -r $(DOCKER) rmi --force \
	|| true
	$(DOCKER) images $(REPOSITORY_ID) \
		--filter=before="$(REPOSITORY_ID):$(*)-$(APP_TAG)" \
		--quiet \
	| xargs -r $(DOCKER) rmi --force \
	|| true

.PHONY: up-and-run
up-and-run: $(MAKE_UP_AND_RUN_DEPENDENCIES) ## build images and start containers

.PHONY: mutagen.start
mutagen.start:
	mutagen project start

.PHONY: mutagen.terminate
mutagen.terminate:
	mutagen project terminate || true

.PHONY: config
config: ## docker-compose config
	$(DC) config $(CMD_ARGS)

.PHONY: start
start: info ## docker-compose start
	$(DC) start $(CMD_ARGS)

.PHONY: restart
restart: info ## docker-compose restart
	$(DC) restart $(CMD_ARGS)

.PHONY: stop
stop: ## docker-compose stop
	$(DC) stop $(CMD_ARGS)

.PHONY: down
down: info ## docker-compose down --remove-orphans
	$(DC) down --remove-orphans $(CMD_ARGS)

.PHONY: logs
logs: ## docker-compose logs -f [service]
	$(DC) logs -f $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: up
up: info ## docker-compose up --detach [service]
	$(DC) up --detach --remove-orphans $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: push
push: login ## push images in registry
	#docker push
	@true

.PHONY: login
login: ## login in docker registry
	$(DOCKER) login

.PHONY: ps
ps: ## show current process list
	$(DC) ps $(CMD_ARGS)

.PHONY: stats
stats: ## docker stats
	$(DOCKER) stats $(CMD_ARGS)

.PHONY: build
build: info $(DOCKER_IMAGES) ## build docker images (all at once)
	echo "build $(strip $(DOCKER_IMAGES)) done."

.PHONY: %.so # build image.so
%.so: cache.%.so
	@#echo "build $* image => "$@" # $@ = php.so | $< = cache.php.so
	@echo "build $* image => $(REPOSITORY_ID):$*-$(COMMIT_ID)"
	$(DOCKER) build \
		--target "$(*)"                             \
		--file "$(DOCKERFILE)"                      \
		--tag "$(REPOSITORY_ID):$(*)-$(COMMIT_ID)"  \
		--cache-from "$(REPOSITORY_ID):$(*)-latest" \
        --label com.best2go="$(APP)"                \
		$(DOCKER_BUILD_ARG_$(call uppercase, $*))   \
		$(DOCKER_BUILD_ARGS)                        \
	    .
	$(DOCKER) tag "$(REPOSITORY_ID):$(*)-$(COMMIT_ID)" "$(REPOSITORY_ID):$(*)-latest"
	$(DOCKER) tag "$(REPOSITORY_ID):$(*)-$(COMMIT_ID)" "$(APP):$(*)"
	# docker inspect -f "{{ index .Config.Labels \"com.$(APP).$*.otp\" }}" ${REPOSITORY_ID}:$*-latest
	# docker inspect -f "{{ index .Config.Labels \"com.$(APP).$*.tag\" }}" ${REPOSITORY_ID}:$*-latest

.PHONY: cache.%.so # pull cache image.so
cache.%.so:
	@echo "pull image '${REPOSITORY_ID}:$*-latest' from registry"
	$(DOCKER_PULL) "${REPOSITORY_ID}:$*-latest" || true


.PHONY: .help
.help: ## Show this help and exit (default target)
	@echo   ''
	@printf "%+21s: \033[94m%s\033[0m \033[90m[%s] [%s]\033[0m\n" "Usage" "make" "target" "ENV_VARIABLE=ENV_VALUE ..."
	@echo   ''
	@echo   '                Available targets:'
	@echo   '                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
	@grep -hE '^[a-zA-Z 0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		 awk 'BEGIN { FS = ":.*?## " }; { printf "\033[36m%+15s\033[0m: %s\n", $$1, $$2 }'
	@echo   '                ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
	@echo   ''


.PHONY: nginx
nginx: info ## make nginx [reload]
	$(NGINX) $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: mysql-ci
mysql-ci: ## echo "show tables" | make mysql-ci
	$(DC_EXEC) -T db \
		mysql --user=$(MYSQL_USER) --password=$(MYSQL_PASSWORD) $(MYSQL_DATABASE) $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: mysql
mysql: ## make mysql
	$(DC_EXEC) db \
		mysql --user=$(MYSQL_USER) --password=$(MYSQL_PASSWORD) $(MYSQL_DATABASE) $(COMMAND_ARGS) $(CMD_ARGS)

.PHONY: .FORCE
.FORCE:

define null_goal =
.PHONY: $1
$1:
	@#echo "null goal - $(1)"
	@true
endef

# if the command starts with "composer", "console", "exec", "up", "logs", "mysql" or "mysql-ci"
# grab the arguments for the command and turn them into null targets
COMMANDS := console composer exec up logs mysql mysql-ci nginx
ifeq ($(firstword $(MAKECMDGOALS)), $(filter $(firstword $(MAKECMDGOALS)),$(COMMANDS)))
    # use the rest as arguments for our real command
    COMMAND_ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
	COMMAND := $(firstword $(MAKECMDGOALS))

    ifneq ($(shell echo "$(COMMAND)_$(COMMAND_ARGS)" | egrep "^exec_$$"),)
        # select default container by priority
    	COMMAND_ARGS := $(or \
    		$(filter xphp, $(DOCKER_IMAGES:.so=)),  \
    		$(filter php, $(DOCKER_IMAGES:.so=)),   \
    		$(filter nginx, $(DOCKER_IMAGES:.so=))  \
    		$(filter db, $(DOCKER_IMAGES:.so=))     \
		)
    endif

    ifneq ($(shell echo "$(COMMAND)_$(COMMAND_ARGS)" | egrep "^exec_(php|xphp|nginx|db)$$"),)
    	COMMAND_ARGS += bash
    endif

    ifneq ($(shell echo "$(COMMAND)_$(COMMAND_ARGS)" | egrep "^nginx_$$"),)
    	COMMAND_ARGS := reload
    endif

    ifneq ($(shell echo "$(COMMAND)_$(COMMAND_ARGS)" | egrep "^nginx_reload$$"),)
    	COMMAND_ARGS := -s reload
    endif

    # turn them into null targets - doesn't work with macos
    $(foreach command, $(COMMAND_ARGS), $(eval $(call null_goal, $(command))))
endif

# should be the last statement to override any target / variable
-include makefile.mk.local
