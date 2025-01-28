%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_redis).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-behaviour(emqx_omp).

-export([
    on_message_acked/3,
    on_session_subscribed/3
]).

%%--------------------------------------------------------------------
%% Action
%%--------------------------------------------------------------------

-spec on_message_acked(Envs :: map(), ConnectorName :: binary(), Opts :: map()) -> ok.
on_message_acked(Envs, ConnectorName, Opts) ->
    ?SLOG(warning, #{
        msg => "on_message_acked", envs => Envs, connector_name => ConnectorName, opts => Opts
    }),
    ok.

-spec on_session_subscribed(Envs :: map(), ConnectorName :: binary(), Opts :: map()) -> ok.
on_session_subscribed(Envs, ConnectorName, Opts) ->
    ?SLOG(warning, #{
        msg => "on_session_subscribed", envs => Envs, connector_name => ConnectorName, opts => Opts
    }),
    ok.
