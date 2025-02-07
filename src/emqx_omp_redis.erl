%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_redis).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").
-include_lib("emqx/include/emqx_hooks.hrl").

-export([
    on_config_changed/2
]).

-define(RESOURCE_ID, <<"omp_redis">>).
-define(RESOURCE_GROUP, <<"omp">>).
-define(TIMEOUT, 1000).

-type context() :: map().

%%--------------------------------------------------------------------
%% Action
%%--------------------------------------------------------------------

-spec on_config_changed(map(), map()) -> ok.
on_config_changed(#{<<"enable">> := false}, #{<<"enable">> := false}) ->
    ok;
on_config_changed(#{<<"enable">> := true} = Conf, #{<<"enable">> := true} = Conf) ->
    ok;
on_config_changed(#{<<"enable">> := true} = _OldConf, #{<<"enable">> := true} = NewConf) ->
    ok = stop(),
    ok = start(NewConf);
on_config_changed(#{<<"enable">> := true} = _OldConf, #{<<"enable">> := false} = _NewConf) ->
    ok = stop();
on_config_changed(#{<<"enable">> := false} = _OldConf, #{<<"enable">> := true} = NewConf) ->
    ok = start(NewConf).

%%--------------------------------------------------------------------
%% start/stop
%%--------------------------------------------------------------------

-spec stop() -> ok.
stop() ->
    ok = stop_resource(),
    unhook().

-spec start(map()) -> ok.
start(ConfigRaw) ->
    ?SLOG(info, #{msg => omp_redis_start, config => ConfigRaw}),
    {RedisConfig, ResourceOpts} = make_redis_resource_config(ConfigRaw),
    ok = start_resource(RedisConfig, ResourceOpts),
    hook(#{}).

%% Resource helpers

make_redis_resource_config(ConfigRaw0) ->
    RedisConfigRaw0 = maps:with([
        <<"servers">>, <<"redis_type">>, <<"pool_size">>, <<"username">>, <<"password">>, <<"database">>, <<"ssl">>
    ], ConfigRaw0),

    RedisConfigRaw1 = fix_servers(RedisConfigRaw0),
    RedisConfigRaw2 = drop_unused_fields(RedisConfigRaw1),
    RedisConfigRaw = maybe_drop_database_field(RedisConfigRaw2),

    RedisConfig = emqx_omp_utils:check_config(emqx_redis, RedisConfigRaw),
    ResourceOpts = emqx_omp_utils:make_resource_opts(ConfigRaw0),

    {RedisConfig, ResourceOpts}.

fix_servers(#{<<"servers">> := Servers, <<"redis_type">> := <<"single">>} = RawConfig0) ->
    RawConfig1 = maps:remove(<<"servers">>, RawConfig0),
    RawConfig1#{<<"server">> => Servers};
fix_servers(RawConfig) ->
    RawConfig.

drop_unused_fields(RawConfig) ->
    lists:foldl(
        fun(Key, Acc) ->
            case Acc of
                #{Key := <<>>} ->
                    maps:remove(Key, Acc);
                _ ->
                    Acc
            end
        end,
        RawConfig,
        [<<"pool_size">>, <<"username">>, <<"password">>, <<"database">>]
    ).

maybe_drop_database_field(#{<<"redis_type">> := <<"cluster">>} = RawConfig) ->
    maps:remove(<<"database">>, RawConfig);
maybe_drop_database_field(RawConfig) ->
    RawConfig.

start_resource(RedisConfig, ResourceOpts) ->
    ?SLOG(info, #{
        msg => omp_redis_resource_start,
        config => RedisConfig,
        resource_opts => ResourceOpts,
        resource_id => ?RESOURCE_ID,
        resource_group => ?RESOURCE_GROUP
    }),
    {ok, _} = emqx_resource:create_local(
        ?RESOURCE_ID,
        ?RESOURCE_GROUP,
        emqx_redis,
        RedisConfig,
        ResourceOpts
    ),
    ok.

stop_resource() ->
    ?SLOG(info, #{
        msg => omp_redis_resource_stop,
        resource_id => ?RESOURCE_ID
    }),
    emqx_resource:remove_local(?RESOURCE_ID).

%% Hook helpers

unhook() ->
    unhook('client.connected', {?MODULE, on_client_connected}),
    unhook('session.subscribed', {?MODULE, on_session_subscribed}),
    unhook('session.unsubscribed', {?MODULE, on_session_unsubscribed}),
    unhook('message.publish', {?MODULE, on_message_publish}),
    unhook('message.acked', {?MODULE, on_message_acked}).

-spec hook(context()) -> ok.
hook(Context) ->
    hook('client.connected', {?MODULE, on_client_connected, [Context]}),
    hook('session.subscribed', {?MODULE, on_session_subscribed, [Context]}),
    hook('session.unsubscribed', {?MODULE, on_session_unsubscribed, [Context]}),
    hook('message.publish', {?MODULE, on_message_publish, [Context]}),
    hook('message.acked', {?MODULE, on_message_acked, [Context]}).

hook(HookPoint, MFA) ->
    %% use highest hook priority so this module's callbacks
    %% are evaluated before the default hooks in EMQX
    emqx_hooks:add(HookPoint, MFA, _Property = ?HP_HIGHEST).

unhook(HookPoint, MFA) ->
    emqx_hooks:del(HookPoint, MFA).

%% Common helpers

% bool_to_int(false) -> 0;
% bool_to_int(true) -> 1.

% int_to_bool(0) -> false;
% int_to_bool(1) -> true.
