%%% @doc describe_mri desk: composite query.
%%%
%%% Returns records + endorsements + backlinks + last_modified +
%%% consensus signal in a single call (PLAN PART1 §4.1). Replaces
%%% what would be 4-6 separate DNS queries.
%%%
%%% Internally fans out parallel sub-queries through resolve_mri,
%%% backlinks, and an endorsement walk. Returns partial results
%%% with a `partial: true' flag when any sub-query fails.
%%%
%%% Phase 0: stub.
%%% @end
-module(describe_mri).
-behaviour(gen_server).

-export([start_link/0, describe/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% @doc Composite description for an MRI.
-spec describe(term(), binary()) -> {ok, map()} | {error, atom()}.
describe(_Pool, _Mri) -> {error, describe_mri_not_yet_implemented}.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
