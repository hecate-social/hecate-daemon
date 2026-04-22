%%% @doc Viewstate computer for briefcase file rows.
%%%
%%% Daemon-side projection that turns raw read-model rows into
%%% UI-ready descriptors: a per-row label, the guard outcome, and a
%%% list of action descriptors (`{id, label, method, url_suffix,
%%% variant, confirm}`) the frontend renders without having to know
%%% any business logic.
%%%
%%% This is the first concrete consumer of the viewstate pattern
%%% (planned in MEMORY.md). Other domains (realm memberships,
%%% plugins, licenses) will follow the same shape.
%%%
%%% Why daemon-side: keeps the frontend purely presentational. When
%%% rules change (new action becomes available, guard state changes
%%% the action set), the daemon updates and the frontend re-renders
%%% without code edits. Matches the user's viewstate feedback.
%%% @end
-module(briefcase_viewstate).

-export([list_files/0, compute_row/1, compute_row/2]).
-export_type([file_view/0, action/0, guard_view/0]).

-type action() :: #{id        := binary(),
                    label     := binary(),
                    method    := binary(),
                    url_suffix := binary(),
                    variant   := binary(),
                    confirm   := binary() | null}.

-type guard_view() :: #{state  := ok | refused | not_applicable,
                        reason := atom() | null}.

-type file_view() :: map().

%%====================================================================
%% API
%%====================================================================

-spec list_files() -> {ok, [file_view()]}.
list_files() ->
    {ok, Rows} = project_briefcase_files_store:list(),
    %% Sort by uploaded_at descending so newest first.
    Sorted = lists:sort(
        fun(A, B) ->
            maps:get(uploaded_at, A, 0) >= maps:get(uploaded_at, B, 0)
        end, Rows),
    {ok, [compute_row(R) || R <- Sorted]}.

-spec compute_row(map()) -> file_view().
compute_row(Row) ->
    compute_row(Row, #{}).

%% @doc Augment `Row` with action list + guard view. `Opts` reserved
%% for future per-call overrides (e.g., suppress guard check for
%% admin views).
-spec compute_row(map(), map()) -> file_view().
compute_row(Row, _Opts) ->
    Guard = guard_for(Row),
    Actions = actions_for(Row, Guard),
    Row#{
        guard => Guard,
        available_actions => Actions
    }.

%%====================================================================
%% Guard
%%====================================================================

guard_for(#{presence := <<"local">>}) ->
    #{state => not_applicable, reason => null};
guard_for(#{file_id := FileId, realm := Realm} = _Row)
  when is_binary(FileId), is_binary(Realm), byte_size(Realm) > 0 ->
    case hecate_license_guard:can_open_file(FileId, Realm) of
        ok ->
            #{state => ok, reason => null};
        {error, Reason} ->
            #{state => refused, reason => Reason}
    end;
guard_for(_) ->
    #{state => not_applicable, reason => null}.

%%====================================================================
%% Actions per (presence, guard) combination
%%====================================================================

actions_for(#{presence := <<"local">>}, _Guard) ->
    [open_action(),
     share_action(),
     unshare_action()];
actions_for(#{presence := <<"remote">>}, #{state := ok}) ->
    [download_action(),
     info_action()];
actions_for(#{presence := <<"remote">>}, #{state := refused}) ->
    %% License refused — show why; the only useful action is "info".
    [info_action()];
actions_for(#{presence := <<"downloading">>}, _Guard) ->
    [progress_action(),
     cancel_download_action()];
actions_for(#{presence := <<"cached">>}, #{state := ok}) ->
    [open_action(),
     evict_action()];
actions_for(#{presence := <<"cached">>}, #{state := refused}) ->
    %% Cached but license now refused (e.g., revoked, stale). Evict
    %% is the only safe action — keeping plaintext-decryptable bytes
    %% around is now policy-violating.
    [evict_action(),
     info_action()];
actions_for(_Row, _Guard) ->
    [].

%%====================================================================
%% Action descriptors
%%====================================================================

open_action() ->
    #{id         => <<"open">>,
      label      => <<"Open">>,
      method     => <<"GET">>,
      url_suffix => <<"/content">>,
      variant    => <<"primary">>,
      confirm    => null}.

share_action() ->
    #{id         => <<"share">>,
      label      => <<"Share to realm">>,
      method     => <<"POST">>,
      url_suffix => <<"/share">>,
      variant    => <<"secondary">>,
      confirm    => null}.

unshare_action() ->
    #{id         => <<"unshare">>,
      label      => <<"Unshare">>,
      method     => <<"POST">>,
      url_suffix => <<"/unshare">>,
      variant    => <<"secondary">>,
      confirm    => null}.

download_action() ->
    #{id         => <<"download">>,
      label      => <<"Download">>,
      method     => <<"POST">>,
      url_suffix => <<"/download">>,
      variant    => <<"primary">>,
      confirm    => null}.

cancel_download_action() ->
    #{id         => <<"cancel_download">>,
      label      => <<"Cancel">>,
      method     => <<"DELETE">>,
      url_suffix => <<"/download">>,
      variant    => <<"danger">>,
      confirm    => <<"Cancel this download?">>}.

progress_action() ->
    %% Not strictly an action — a UI affordance to poll the progress
    %% endpoint. Frontend turns this into a progress bar component
    %% rather than a button.
    #{id         => <<"progress">>,
      label      => <<"Downloading">>,
      method     => <<"GET">>,
      url_suffix => <<"/download">>,
      variant    => <<"info">>,
      confirm    => null}.

evict_action() ->
    #{id         => <<"evict">>,
      label      => <<"Evict cache">>,
      method     => <<"DELETE">>,
      url_suffix => <<"/cache">>,
      variant    => <<"danger">>,
      confirm    => <<"Drop the cached copy? You can re-download.">>}.

info_action() ->
    #{id         => <<"info">>,
      label      => <<"Details">>,
      method     => <<"GET">>,
      url_suffix => <<"">>,                %% the bare /:id endpoint
      variant    => <<"secondary">>,
      confirm    => null}.
