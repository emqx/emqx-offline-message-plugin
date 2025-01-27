%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_offline_message_plugin_SUITE).

-include_lib("eunit/include/eunit.hrl").

-compile(nowarn_export_all).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

all() ->
    emqx_offline_message_plugin_test_helpers:all(?MODULE).

init_per_suite(Config) ->
    ok = emqx_offline_message_plugin_test_helpers:init_cth(),
    SuiteApps = emqx_cth_suite:start(
        [{emqx, #{override_env => [{boot_modules, [broker]}]}}],
        #{work_dir => emqx_cth_suite:work_dir(Config)}
    ),
    {ok, _} = application:ensure_all_started(emqx_offline_message_plugin),
    [{apps, SuiteApps} | Config].

end_per_suite(Config) ->
    SuiteApps = ?config(apps, Config),
    _ = emqx_cth_suite:stop(SuiteApps),
    ok = application:stop(emqx_offline_message_plugin),
    ok.

t_ok(_Config) ->
    ok.

