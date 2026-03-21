%%% @doc Mesh proof probe: content-addressed store + fetch.
%%%
%%% Stores a random payload via macula_content, retrieves it by
%%% MCID, and verifies the fetched data matches. Proves the
%%% content-addressed storage pipeline works.
%%% @end
-module(probe_mesh_content).

-export([run/1]).

-spec run(pid()) -> {ok, map()} | {error, term()}.
run(_Client) ->
    Payload = <<"hecate-proof-", (crypto:strong_rand_bytes(16))/binary>>,
    Start = erlang:monotonic_time(millisecond),
    case macula_content:store(Payload) of
        {ok, Manifest} ->
            MCID = macula_content:mcid(Payload),
            case macula_content:fetch(MCID) of
                {ok, Fetched} when Fetched =:= Payload ->
                    Elapsed = erlang:monotonic_time(millisecond) - Start,
                    MCIDStr = macula_content:mcid_to_string(MCID),
                    {ok, #{
                        mcid => MCIDStr,
                        size => byte_size(Payload),
                        round_trip_ms => Elapsed,
                        manifest_chunks => length(macula_content:get_chunks(Manifest))
                    }};
                {ok, _Other} ->
                    {error, content_mismatch};
                {error, Reason} ->
                    {error, {fetch_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {store_failed, Reason}}
    end.
