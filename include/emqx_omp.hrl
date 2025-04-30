%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-define(METRICS_WORKER, emqx_omp_metrics_worker).
-define(PLUGIN_NAME, emqx_offline_message_plugin).

%% Do not update version manually, use make bump-version-patch/minor/major instead
-define(PLUGIN_RELEASE_VERSION, "1.0.1").

-define(PLUGIN_NAME_VSN, <<"emqx_offline_message_plugin-", ?PLUGIN_RELEASE_VERSION>>).
