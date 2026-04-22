%%% @doc Admin endpoint: GET /api/admin/briefcase/guard/:file_id
%%%
%%% Returns the current guard outcome for a file plus the underlying
%%% accepted-license entry (if any). Used by the fleet CT suite + by
%%% operators to debug "why is the open path returning 403?".
%%%
%%% Bearer-auth via `hecate_admin_auth` — if `HECATE_ADMIN_TOKEN`
%%% isn't set the endpoint returns 503.
%%% @end
-module(admin_guard_inspect_api).

-export([init/2, routes/0]).

routes() -> [{"/api/admin/briefcase/guard/:file_id", ?MODULE, []}].

init(Req0, State) ->
    case hecate_admin_auth:authorise(Req0) of
        ok            -> dispatch(Req0, State);
        {error, _, R} -> {ok, R, State}
    end.

dispatch(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    FileId = cowboy_req:binding(file_id, Req0),
    Realm = case cowboy_req:parse_qs(Req0) of
        Qs when is_list(Qs) ->
            proplists:get_value(<<"realm">>, Qs, undefined);
        _ -> undefined
    end,
    case {FileId, Realm} of
        {<<>>, _}      -> hecate_api_utils:json_error(400, <<"missing file_id">>, Req0);
        {_, undefined} -> hecate_api_utils:json_error(400, <<"missing realm query param">>, Req0);
        _              -> respond(FileId, Realm, Req0)
    end.

respond(FileId, Realm, Req0) ->
    Guard = hecate_license_guard:can_open_file(FileId, Realm),
    License = case project_share_licenses_store:get_accepted_by_file_id(FileId) of
        {ok, L} -> serialise_license(L);
        _       -> null
    end,
    LastCatchup = hecate_license_guard:last_catchup(Realm),
    hecate_api_utils:json_ok(#{
        file_id => FileId,
        realm => Realm,
        guard => guard_to_payload(Guard),
        license => License,
        realm_last_catchup_at => to_json_value(LastCatchup),
        now => erlang:system_time(millisecond)
    }, Req0).

guard_to_payload(ok) ->
    #{state => <<"ok">>, reason => null};
guard_to_payload({error, Reason}) ->
    #{state => <<"refused">>, reason => atom_to_binary(Reason, utf8)}.

serialise_license(License) ->
    %% Trim sensitive fields — sealed CEK + wrapped CEK aren't
    %% meaningful in JSON and aren't safe to surface even via admin
    %% (constant-time inspection bonus).
    Slim = maps:without([wrapped_cek, accepted_cek_sealed], License),
    maps:map(fun(_, V) -> to_json_value(V) end, Slim).

to_json_value(undefined)             -> null;
to_json_value(A) when is_atom(A)     -> atom_to_binary(A, utf8);
to_json_value(I) when is_integer(I)  -> I;
to_json_value(B) when is_binary(B)   -> B;
to_json_value(L) when is_list(L)     -> [to_json_value(X) || X <- L];
to_json_value(Other)                 -> iolist_to_binary(io_lib:format("~p", [Other])).
