%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp).


-include("emqx_omp.hrl").
-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-export([
    action/3,
    load/0,
    unload/0
]).

-type event_message_acked() :: #{
    event := 'message.acked',
    node := node(),
    timestamp := integer(),
    _ => _
}.

-type event_session_subscribed() :: #{
    event := 'session.subscribed',
    node := node(),
    timestamp := integer(),
    _ => _
}.

-type opts() :: map().
-type resource_id() :: binary().

-callback on_message_acked(event_message_acked(), resource_id(), opts()) -> ok | error.
-callback on_session_subscribed(event_session_subscribed(), resource_id(), opts()) -> ok | error.

%%--------------------------------------------------------------------
%% Load/Unload
%%--------------------------------------------------------------------

-spec load() -> ok | error.
load() ->
    emqx_metrics_worker:create_metrics(
        ?METRICS_WORKER, message_acked, [success, fail]
    ),
    emqx_metrics_worker:create_metrics(
        ?METRICS_WORKER, session_subscribed, [success, fail]
    ),
    ok.

-spec unload() -> ok | error.
unload() ->
    ok.

%%--------------------------------------------------------------------
%% Action
%%--------------------------------------------------------------------
action(_Selected, Envs, #{connector_name := ConnectorName, opts := Opts}) ->
    case module_name(ConnectorName) of
        {ok, Module} ->
            action(Module, Envs, ConnectorName, Opts);
        {error, _} = Error ->
            Error
    end;
action(_Selected, _Envs, _Args) ->
    ?SLOG(warning, #{msg => "unknown_event", selected => _Selected, envs => _Envs, args => _Args}),
    ok.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

action(Module, #{event := 'message.acked'} = Envs, ConnectorName, Opts) ->
    Module:on_message_acked(Envs, ConnectorName, Opts);
action(Module, #{event := 'session.subscribed'} = Envs, ConnectorName, Opts) ->
    Module:on_session_subscribed(Envs, ConnectorName, Opts);
action(_Module, _Envs, _ConnectorName, _Opts) ->
    ?SLOG(warning, #{msg => "unknown_event", envs => _Envs, connector_name => _ConnectorName, opts => _Opts}),
    ok.

module_name(<<"redis:", _/binary>>) ->
    {ok, emqx_omp_redis};
module_name(<<"mysql:", _/binary>>) ->
    {ok, emqx_omp_mysql};
module_name(ConnectorName) ->
    {error, {unknown_connector_type, ConnectorName}}.
