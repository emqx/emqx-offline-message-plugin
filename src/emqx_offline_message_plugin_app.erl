%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_offline_message_plugin_app).

-behaviour(application).

-emqx_plugin(?MODULE).

-export([
    start/2,
    stop/1
]).

start(_StartType, _StartArgs) ->
    {ok, Sup} = emqx_offline_message_plugin_sup:start_link(),
    emqx_offline_message_plugin:load(application:get_all_env()),

    % emqx_ctl:register_command(offline_message, {emqx_offline_message_plugin_cli, cmd}),
    {ok, Sup}.

stop(_State) ->
    % emqx_ctl:unregister_command(offline_message),
    emqx_offline_message_plugin:unload().
