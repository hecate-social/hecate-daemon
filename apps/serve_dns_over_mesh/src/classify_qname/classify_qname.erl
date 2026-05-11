%%% @doc Classifies a qname as mesh-eligible (suffix matches the
%%% configured `mesh_suffix' app env, default `macula.io.') or
%%% non-mesh (the bridge then answers REFUSED — it never tries to
%%% resolve names outside its synthetic suffix).
%%%
%%% Comparison is case-insensitive (DNS is); the qname is
%%% lowercased before the suffix check. A trailing dot on either
%%% side is normalised away.
%%%
%%% The reverse-arpa zones (`*.ip6.arpa.', `*.in-addr.arpa.') are
%%% NOT classified mesh here — reverse lookups are handled by the
%%% dedicated reverse path (`qname_reverse_v6'); a query for those
%%% that isn't a mesh-allocated prefix falls through to REFUSED at
%%% that layer. classify_qname's job is only the forward
%%% `*.<mesh_suffix>' check.
%%% @end
-module(classify_qname).

-export([classify/1, mesh_suffix/0]).

-define(DEFAULT_MESH_SUFFIX, <<"macula.io.">>).

%% @doc `mesh' if the qname is under the configured mesh suffix,
%% `not_mesh' otherwise.
-spec classify(QName :: binary()) -> mesh | not_mesh.
classify(QName) when is_binary(QName) ->
    Norm   = strip_trailing_dot(string:lowercase(QName)),
    Suffix = strip_trailing_dot(mesh_suffix()),
    case has_suffix(Norm, Suffix) of
        true  -> mesh;
        false -> not_mesh
    end;
classify(_) ->
    not_mesh.

%% @doc The configured mesh suffix as a lowercase binary WITH a
%% trailing dot (e.g., `<<"macula.io.">>'). Reads
%% `application:get_env(serve_dns_over_mesh, mesh_suffix, ...)';
%% accepts either a binary or a string in the env.
-spec mesh_suffix() -> binary().
mesh_suffix() ->
    Raw = application:get_env(serve_dns_over_mesh, mesh_suffix,
                              ?DEFAULT_MESH_SUFFIX),
    Bin = case is_list(Raw) of
              true  -> list_to_binary(Raw);
              false -> Raw
          end,
    Lower = string:lowercase(Bin),
    case binary:last(Lower) of
        $. -> Lower;
        _  -> <<Lower/binary, ".">>
    end.

%%====================================================================
%% Helpers
%%====================================================================

strip_trailing_dot(<<>>) -> <<>>;
strip_trailing_dot(B) ->
    case binary:last(B) of
        $. -> binary:part(B, 0, byte_size(B) - 1);
        _  -> B
    end.

%% True if `Full' equals `Suffix' or ends with `.' ++ `Suffix'.
%% (A bare `<<>>' suffix matches nothing — defensive.)
has_suffix(_Full, <<>>) ->
    false;
has_suffix(Full, Suffix) ->
    Full =:= Suffix orelse
        binary:longest_common_suffix([Full, <<".", Suffix/binary>>])
            =:= byte_size(Suffix) + 1.
