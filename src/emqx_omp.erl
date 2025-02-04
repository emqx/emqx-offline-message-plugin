%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp).

-include("emqx_omp.hrl").
-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-export([
    load/0,
    unload/0,
    current_config/0
]).

-export([
    on_config_changed/2
]).

%%--------------------------------------------------------------------
%% Load/Unload
%%--------------------------------------------------------------------

-spec load() -> ok.
load() ->
    ?SLOG(info, #{msg => "omp_load"}),
    emqx_metrics_worker:create_metrics(
        ?METRICS_WORKER, message_acked, [success, fail]
    ),
    emqx_metrics_worker:create_metrics(
        ?METRICS_WORKER, session_subscribed, [success, fail]
    ),

    ok = on_config_changed(#{}, current_config()),
    ok.

-spec unload() -> ok.
unload() ->
    ok = on_config_changed(current_config(), #{}),
    ok.

current_config() ->
    {ok, Config} = emqx_plugins:get_config(?PLUGIN_NAME_VSN),
    Config.

%%--------------------------------------------------------------------
%% EMQX Plugin callbacks
%%--------------------------------------------------------------------

-spec on_config_changed(map(), map()) -> ok.
on_config_changed(OldConf, NewConf) ->
    ?SLOG(info, #{
        msg => "offline_message_plugin_config_changed", old_conf => OldConf, new_conf => NewConf
    }),
    DefaultConf = #{<<"enable">> => false},
    OldMysqlConf = maps:get(<<"mysql">>, OldConf, DefaultConf),
    OldRedisConf = maps:get(<<"redis">>, OldConf, DefaultConf),
    NewMysqlConf = maps:get(<<"mysql">>, NewConf, DefaultConf),
    NewRedisConf = maps:get(<<"redis">>, NewConf, DefaultConf),
    ok = emqx_omp_mysql:on_config_changed(OldMysqlConf, NewMysqlConf),
    ok = emqx_omp_redis:on_config_changed(OldRedisConf, NewRedisConf),
    ok.

