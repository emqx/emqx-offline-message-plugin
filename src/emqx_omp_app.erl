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
    emqx_omp:load(application:get_all_env()),

    % emqx_ctl:register_command(offline_message, {emqx_omp_cli, cmd}),
    {ok, Sup}.

stop(_State) ->
    % emqx_ctl:unregister_command(offline_message),
    emqx_omp:unload().
