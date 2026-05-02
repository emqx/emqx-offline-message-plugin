%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_offline_message_plugin_app).

-include_lib("emqx/include/logger.hrl").

-behaviour(application).

-emqx_plugin(?MODULE).

%% Application callbacks
-export([
    start/2,
    stop/1
]).

%% EMQX Plugin callbacks
-export([
    on_config_changed/2,
    on_health_check/1
]).

start(_StartType, _StartArgs) ->
    {ok, Sup} = emqx_omp_sup:start_link(),
    {ok, Sup}.

stop(_State) ->
    ok.

on_config_changed(OldConf, NewConf) ->
    emqx_omp:on_config_changed(OldConf, NewConf).

on_health_check(_Options) ->
    emqx_omp:on_health_check().
