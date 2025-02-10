%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_utils).

-export([
    fix_ssl_config/1,
    make_resource_opts/1,
    check_config/2,
    deliver_messages/2,
    induce_subscriptions/1
]).

fix_ssl_config(#{<<"ssl">> := SslConfig0} = RawConfig) ->
    SslConfig = maps:filter(
        fun
            (_K, <<>>) ->
                false;
            (_K, _V) ->
                true
        end,
        SslConfig0
    ),
    RawConfig#{<<"ssl">> => SslConfig};
fix_ssl_config(RawConfig) ->
    RawConfig#{<<"ssl">> => #{<<"enable">> => false}}.

make_resource_opts(RawConfig) ->
    #{
        start_after_created => true,
        batch_size => maps:get(<<"batch_size">>, RawConfig, 0),
        batch_time => maps:get(<<"batch_time">>, RawConfig, 100)
    }.

check_config(Schema, ConfigRaw) ->
    case
        emqx_hocon:check(
            Schema,
            #{<<"config">> => ConfigRaw},
            #{atom_key => true}
        )
    of
        {ok, #{config := Config}} ->
            Config;
        {error, Reason} ->
            error({invalid_config, Reason})
    end.

deliver_messages(Topic, Messages) ->
    lists:foreach(
        fun(Message) ->
            erlang:send(self(), {deliver, Topic, Message})
        end,
        Messages
    ).

induce_subscriptions([]) ->
    ok;
induce_subscriptions(Subscriptions) ->
    erlang:send(self(), {subscribe, Subscriptions}),
    ok.
