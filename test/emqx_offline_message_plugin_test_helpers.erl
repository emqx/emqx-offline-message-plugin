%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_offline_message_plugin_test_helpers).

-export([
    init_cth/0,
    is_tcp_server_available/2,
    all/1
]).

all(Suite) ->
    ensure_test_module(emqx_common_test_helpers),
    emqx_common_test_helpers:all(Suite).

init_cth() ->
    ensure_test_module(emqx_common_test_helpers),
    ensure_test_module(emqx_cth_suite),
    ok.

is_tcp_server_available(Host, Port) ->
    ensure_test_module(emqx_common_test_helpers),
    emqx_common_test_helpers:is_tcp_server_available(Host, Port).

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

ensure_test_module(M) ->
    false == code:is_loaded(M) andalso
        compile_emqx_test_module(M).

compile_emqx_test_module(M) ->
    EmqxDir = code:lib_dir(emqx),
    AppDir = code:lib_dir(emqx_offline_message_plugin),
    MFilename = filename:join([EmqxDir, "test", M]),
    OutDir = filename:join([AppDir, "test"]),
    {ok, _} = compile:file(MFilename, [{outdir, OutDir}]),
    ok.
