%%% @doc RPC handler: `<realm>.briefcase.get_chunk`.
%%%
%%% Serves content bytes from the local briefcase_content_store when
%%% another peer in the realm requests them. Called from the mesh
%%% subscriber flow on peers that do not yet have the content locally.
%%%
%%% Args (incoming call payload):
%%%     #{ file_id => binary() }
%%%
%%% Reply:
%%%     {ok, #{ file_id => binary(),
%%%             size    => non_neg_integer(),
%%%             bytes   => binary() }}
%%%   | {error, not_available}
%%%
%%% Phase 2 serves whole files. Phase 3 replaces this with true chunk
%%% fetches (keyed by content-addressed chunk hash).
%%% @end
-module(serve_file_content_rpc).

-export([procedure/0, handle/1, register/0]).

-spec procedure() -> binary().
procedure() ->
    hecate_topics:app_hope(<<"briefcase">>, <<"get_chunk">>, 1).

%% @doc RPC handler. Signature matches macula:advertise expectations.
-spec handle(map()) -> {ok, map()} | {error, term()}.
handle(#{<<"file_id">> := FileId}) ->
    handle_file_id(FileId);
handle(#{file_id := FileId}) ->
    handle_file_id(FileId);
handle(_) ->
    {error, missing_file_id}.

handle_file_id(FileId) when is_binary(FileId) ->
    case briefcase_content_store:get(FileId) of
        {ok, Bytes} ->
            {ok, #{
                file_id => FileId,
                size    => byte_size(Bytes),
                bytes   => Bytes
            }};
        {error, enoent} ->
            {error, not_available};
        {error, Reason} ->
            {error, Reason}
    end;
handle_file_id(_) ->
    {error, invalid_file_id}.

%% @doc Register the advertisement with the mesh client. Safe to call
%% at boot — the subscription is queued until the mesh activates.
-spec register() -> ok.
register() ->
    hecate_mesh_client:register_advertisement(
        procedure(),
        fun ?MODULE:handle/1
    ).
