## to build emqtt without QUIC
export BUILD_WITHOUT_QUIC = 1

## Feature Used in rebar plugin emqx_plugrel
## The Feature have not enabled by default on OTP25
export ERL_FLAGS ?= -enable-feature maybe_expr

REBAR = $(CURDIR)/rebar3
SCRIPTS = $(CURDIR)/scripts

PLUGREL_DIR = $(CURDIR)/_build/default/emqx_plugrel
TEST_ASSETS_DIR = $(CURDIR)/_build/test/lib/emqx_offline_message_plugin/test/assets

.PHONY: all
all: compile

.PHONY: ensure-rebar3
ensure-rebar3:
	@$(SCRIPTS)/ensure-rebar3.sh

$(REBAR):
	$(MAKE) ensure-rebar3

.PHONY: compile
compile: $(REBAR)
	$(REBAR) compile

.PHONY: shell
shell: $(REBAR)
	$(REBAR) as test shell

.PHONY: ct
ct: $(REBAR) rel copy-plugin
	$(REBAR) as test ct -v --readable=true

.PHONY: eunit
eunit: $(REBAR)
	$(REBAR) as test eunit

.PHONY: cover
cover: $(REBAR)
	$(REBAR) cover

.PHONY: clean
clean:
	@rm -rf test/emqx

.PHONY: distclean
distclean: clean
	@rm -rf _build
	@rm -f rebar.lock

.PHONY: rel
rel: $(REBAR)
	@rm -rf $(PLUGREL_DIR)
	$(REBAR) emqx_plugrel tar

.PHONY: copy-plugin
copy-plugin:
	@mkdir -p $(TEST_ASSETS_DIR)
	@rm -rf $(TEST_ASSETS_DIR)/emqx_offline_message_plugin-*.tar.gz
	@cp -r $(PLUGREL_DIR)/emqx_offline_message_plugin-*.tar.gz $(TEST_ASSETS_DIR)/

.PHONY: fmt
fmt: $(REBAR)
	$(REBAR) fmt --verbose -w

.PHONY: fmt-check
fmt-check: $(REBAR)
	$(REBAR) fmt --verbose --check

.PHONY: up
up:
	docker compose up --detach --build --force-recreate

.PHONY: down
down:
	docker compose down --volumes

# bump-version-patch/minor/major
.PHONY: bump-version-%
bump-version-%:
	./scripts/bumpversion.sh $*

