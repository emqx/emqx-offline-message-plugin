%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_offline_message_plugin_cli).

-export([cmd/1]).

cmd(_) ->
    emqx_ctl:usage([{"offline_message status", "Print the status of offline message plugin"}]).
