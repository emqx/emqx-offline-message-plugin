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
    ?SLOG(info, #{msg => omp_redis_stop}),
    ok.

-spec start(map()) -> ok.
start(ConfigRaw) ->
    ?SLOG(info, #{msg => omp_redisstart, config => ConfigRaw}),
    ok.
