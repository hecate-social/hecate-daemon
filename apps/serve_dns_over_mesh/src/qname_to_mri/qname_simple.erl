%%% @doc Helper for "simple" MRI types — those whose label algebra
%%% is just `reverse(left-of-disc labels) → path' and
%%% `reverse(right-of-disc labels) → realm'.
%%%
%%% Two entry points:
%%%   - `resolve/3' — the per-type modules (qname_user, qname_app,
%%%     qname_service, qname_device) call this with the raw
%%%     left/right DNS labels; it does the reversal + MRI build.
%%%     This is the "construct a simple-type MRI from labels"
%%%     surface a direct caller (a TUI name editor, a test) would
%%%     use.
%%%   - `from_components/3' — the qname_to_mri dispatcher calls this
%%%     once it has already assembled the Type/Realm/Path tuple
%%%     (it has to do its own multi-discriminator walk anyway, so
%%%     it builds the path then hands it here for the macula_mri:new
%%%     validation).
%%%
%%% Special-case types (qname_proc, qname_topic, qname_station,
%%% qname_org, qname_reverse_v6) have their own modules.
%%% @end
-module(qname_simple).

-export([resolve/3, from_components/3]).

%% @doc Build a simple-type MRI from the DNS labels left and right
%% of the type discriminator (both in DNS leftmost-first order).
-spec resolve(Type :: atom(), Left :: [binary()], Right :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
resolve(_Type, [], _Right) ->
    {error, malformed_qname};
resolve(_Type, _Left, []) ->
    {error, malformed_qname};
resolve(Type, Left, Right) ->
    from_components(Type, labels_to_realm(Right), lists:reverse(Left)).

%% @doc Build + validate an MRI from an already-assembled
%% Type/Realm/Path tuple via macula_mri:new/3.
-spec from_components(Type :: atom(), Realm :: binary(),
                      Path :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
from_components(Type, Realm, Path) ->
    case macula_mri:new(Type, Realm, Path) of
        {ok, Mri}      -> {ok, Mri};
        {error, _} = E -> E
    end.

%% DNS labels in leftmost-first order; reverse to MRI realm form
%% (e.g., [<<"macula">>, <<"io">>] → <<"io.macula">>).
labels_to_realm(DnsLabels) ->
    iolist_to_binary(lists:join(<<".">>, lists:reverse(DnsLabels))).
