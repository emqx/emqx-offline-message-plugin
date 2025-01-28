%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_sup).

-include("emqx_omp.hrl").

-behaviour(supervisor).

-export([start_link/0]).

-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    ChildSpec = emqx_metrics_worker:child_spec(
        ?METRICS_WORKER,
        emqx_omp_metrics_worker
    ),
    {ok, {{one_for_all, 0, 1}, [ChildSpec]}}.
