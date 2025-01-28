%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_app).

-behaviour(application).

-emqx_plugin(?MODULE).

-export([
    start/2,
    stop/1
]).

start(_StartType, _StartArgs) ->
    {ok, Sup} = emqx_omp_sup:start_link(),
    ok = emqx_omp:load(),
    {ok, Sup}.

stop(_State) ->
    ok = emqx_omp:unload(),
    ok.
