#!/usr/bin/env bash
#
# Execute an Erlang expression on the running dev daemon via RPC.
#
# Usage:
#   ./scripts/dev-rpc.sh 'erlang:node().'
#   ./scripts/dev-rpc.sh 'whereis(app_martha_sup).'
#   ./scripts/dev-rpc.sh   # no args → interactive remote shell
#
set -euo pipefail

NODE_HOST="$(cat /etc/hostname 2>/dev/null || uname -n)"
TARGET="hecate_dev@${NODE_HOST}"
COOKIE="hecate_dev_cookie"

if [ $# -eq 0 ]; then
    exec erl -sname "hecate_remsh_$$" -setcookie "$COOKIE" -remsh "$TARGET" -hidden
fi

EXPR="$1"

# Write a temporary module that evaluates the expression via rpc:call
# Using a temp .escript avoids all shell escaping issues
TMPFILE="$(mktemp /tmp/dev_rpc_XXXXXX.escript)"
cat > "$TMPFILE" << 'ESCRIPT_EOF'
#!/usr/bin/env escript
%%! -sname hecate_probe -setcookie hecate_dev_cookie -hidden

main([TargetStr, ExprStr]) ->
    Target = list_to_atom(TargetStr),
    case net_adm:ping(Target) of
        pong -> ok;
        pang ->
            io:format("ERROR: daemon not running (~s)~n", [TargetStr]),
            halt(1)
    end,
    {ok, Tokens, _} = erl_scan:string(ExprStr),
    {ok, Exprs} = erl_parse:parse_exprs(Tokens),
    case rpc:call(Target, erl_eval, exprs, [Exprs, []]) of
        {value, Val, _} ->
            io:format("~p~n", [Val]);
        {badrpc, Reason} ->
            io:format("RPC error: ~p~n", [Reason]),
            halt(1)
    end.
ESCRIPT_EOF

escript "$TMPFILE" "$TARGET" "$EXPR"
RC=$?
rm -f "$TMPFILE"
exit $RC
