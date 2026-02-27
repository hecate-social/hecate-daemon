%%%-------------------------------------------------------------------
%%% @doc Hecate CLI - A nice command-line interface.
%%%
%%% Usage:
%%%   hecate init              Initialize identity
%%%   hecate join              Join a Realm (OAuth flow)
%%%   hecate status            Show current status
%%%   hecate start             Start the daemon
%%%   hecate stop              Stop the daemon
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_cli).

-export([main/1]).

%% Suppress dialyzer warnings for calls to qrcode (excluded from PLT)
-dialyzer({nowarn_function, [generate_qr/1]}).

%% ANSI color codes
-define(RESET,   "\e[0m").
-define(BOLD,    "\e[1m").
-define(DIM,     "\e[2m").
-define(RED,     "\e[31m").
-define(GREEN,   "\e[32m").
-define(YELLOW,  "\e[33m").
-define(BLUE,    "\e[34m").
-define(MAGENTA, "\e[35m").
-define(CYAN,    "\e[36m").
-define(WHITE,   "\e[37m").
-define(BG_BLACK, "\e[40m").

%% Box drawing
-define(TOP_LEFT,     "╭").
-define(TOP_RIGHT,    "╮").
-define(BOT_LEFT,     "╰").
-define(BOT_RIGHT,    "╯").
-define(HORIZONTAL,   "─").
-define(VERTICAL,     "│").
-define(CROSS,        "┼").

%% Icons
-define(ICON_KEY,     "🗝️ ").
-define(ICON_CHECK,   "✓").
-define(ICON_CROSS,   "✗").
-define(ICON_ARROW,   "→").
-define(ICON_DOT,     "●").
-define(ICON_WAIT,    "◌").

main(Args) ->
    case parse_args(Args) of
        {ok, {Command, Opts}} ->
            run_command(Command, Opts);
        {error, Reason} ->
            print_error(Reason),
            show_usage(),
            halt(1)
    end.

parse_args([]) ->
    {ok, {help, []}};
parse_args(["help" | _]) ->
    {ok, {help, []}};
parse_args(["--help" | _]) ->
    {ok, {help, []}};
parse_args(["-h" | _]) ->
    {ok, {help, []}};
parse_args(["init" | Rest]) ->
    {ok, {init, Rest}};
parse_args(["join" | Rest]) ->
    {ok, {join, Rest}};
parse_args(["status" | Rest]) ->
    {ok, {status, Rest}};
parse_args(["start" | Rest]) ->
    {ok, {start, Rest}};
parse_args(["stop" | Rest]) ->
    {ok, {stop, Rest}};
parse_args(["version" | _]) ->
    {ok, {version, []}};
parse_args([Unknown | _]) ->
    {error, {unknown_command, Unknown}}.

run_command(help, _) ->
    show_usage();
run_command(version, _) ->
    show_version();
run_command(init, _Opts) ->
    cmd_init();
run_command(join, _Opts) ->
    cmd_join();
run_command(status, Opts) ->
    cmd_status(lists:member("-w", Opts) orelse lists:member("--watch", Opts));
run_command(start, _Opts) ->
    cmd_start();
run_command(stop, _Opts) ->
    cmd_stop().

%%%===================================================================
%%% Commands
%%%===================================================================

cmd_init() ->
    print_header("Initializing Hecate"),
    
    %% Ensure app is started for identity generation
    ensure_started(),
    
    case hecate_identity:initialize(#{}) of
        ok ->
            print_success("Identity created"),
            {ok, MRI} = hecate_identity:get_mri(),
            {ok, PubKey} = hecate_identity:get_public_key(),
            io:format("~n"),
            print_kv("MRI", binary_to_list(MRI)),
            print_kv("Public Key", truncate_key(PubKey)),
            io:format("~n"),
            print_info("Run 'hecate join' to link with your Realm account");
        {error, already_initialized} ->
            print_warning("Identity already exists"),
            {ok, MRI} = hecate_identity:get_mri(),
            print_kv("MRI", binary_to_list(MRI));
        {error, Reason} ->
            print_error(io_lib:format("Failed to initialize: ~p", [Reason])),
            halt(1)
    end.

cmd_join() ->
    print_header("Joining Realm"),

    ensure_started(),

    case hecate_realm_session:start_joining(#{}) of
        {ok, #{session_id := _SessionId,
               joining_url := Url} = Data} ->
            show_join_screen(Url, Data);
        {error, identity_not_initialized} ->
            print_error("Identity not initialized"),
            print_info("Run 'hecate init' first"),
            halt(1);
        {error, Reason} ->
            print_error(io_lib:format("Failed to start joining: ~p", [Reason])),
            halt(1)
    end.

cmd_status(Watch) ->
    ensure_started(),
    
    case Watch of
        true -> watch_status();
        false -> show_status_once()
    end.

cmd_start() ->
    print_header("Starting Hecate"),
    %% This would typically use the release script
    print_info("Use: _build/default/rel/hecate/bin/hecate start"),
    print_dim("Or run in foreground: rebar3 shell").

cmd_stop() ->
    print_header("Stopping Hecate"),
    print_info("Use: _build/default/rel/hecate/bin/hecate stop").

%%%===================================================================
%%% Join Screen
%%%===================================================================

show_join_screen(Url, _Data) ->
    %% Clear screen and hide cursor
    io:format("\e[2J\e[H\e[?25l"),

    %% Generate QR code
    QrLines = generate_qr(Url),

    %% Print join box
    print_join_box(QrLines, Url),

    %% Start polling loop
    poll_join_status(),

    %% Show cursor again
    io:format("\e[?25h").

print_join_box(QrLines, Url) ->
    Width = 64,

    %% Header
    io:format("~n"),
    print_box_line(top, Width),
    print_box_content(Width, ?BOLD ++ ?CYAN ++ ?ICON_KEY ++ " Join Realm" ++ ?RESET),
    print_box_separator(Width),

    %% QR Code
    print_box_content(Width, ?DIM ++ "Scan with your phone:" ++ ?RESET),
    io:format("~s~n", [?VERTICAL]),
    lists:foreach(fun(Line) ->
        Padded = center_text(Line, Width - 2),
        io:format("~s ~s ~s~n", [?VERTICAL, Padded, ?VERTICAL])
    end, QrLines),
    io:format("~s~n", [?VERTICAL]),

    %% URL
    print_box_content(Width, ?DIM ++ "Or visit:" ++ ?RESET),
    print_box_content(Width, ?CYAN ++ binary_to_list(Url) ++ ?RESET),
    io:format("~s~n", [?VERTICAL]),

    %% Footer
    print_box_separator(Width),
    print_box_content(Width, ?DIM ++ ?ICON_WAIT ++ " Log in via the browser to join..." ++ ?RESET),
    print_box_line(bottom, Width),
    io:format("~n").

poll_join_status() ->
    timer:sleep(1000),
    Status = hecate_realm_session:get_status(),
    case maps:get(status, Status, idle) of
        joined ->
            show_join_success();
        failed ->
            Error = maps:get(error, Status, unknown),
            show_join_failed(Error);
        joining ->
            %% Update countdown
            ExpiresIn = maps:get(expires_in, Status, 0),
            update_countdown(ExpiresIn),
            poll_join_status();
        _ ->
            show_join_failed(cancelled)
    end.

update_countdown(Seconds) ->
    %% Move cursor to countdown line and update
    Mins = Seconds div 60,
    Secs = Seconds rem 60,
    TimeStr = io_lib:format("~2..0B:~2..0B", [Mins, Secs]),

    %% Move up and update the waiting line
    io:format("\e[3A\r"),
    io:format("~s ~s Log in via the browser to join... (~s remaining)     ~s~n",
              [?VERTICAL, ?DIM ++ ?ICON_WAIT, TimeStr, ?RESET]),
    io:format("\e[2B").

show_join_success() ->
    io:format("\e[2J\e[H"),
    print_header(?GREEN ++ ?ICON_CHECK ++ " Joined Realm!" ++ ?RESET),
    io:format("~n"),

    %% Get the new identity info
    case hecate_store:get(<<"auth">>, <<"org_identity">>) of
        {ok, OrgId} ->
            print_kv("Organization", binary_to_list(OrgId));
        _ -> ok
    end,

    io:format("~n"),
    print_success("Your agent is now connected to the Macula mesh"),
    print_info("Run 'hecate status' to see connection details"),
    io:format("~n").

-spec show_join_failed(term()) -> no_return().
show_join_failed(Reason) ->
    io:format("\e[2J\e[H"),
    print_header(?RED ++ ?ICON_CROSS ++ " Join Failed" ++ ?RESET),
    io:format("~n"),
    print_error(io_lib:format("Reason: ~p", [Reason])),
    print_info("Run 'hecate join' to try again"),
    io:format("~n"),
    halt(1).

%%%===================================================================
%%% Status Display
%%%===================================================================

show_status_once() ->
    print_header("Hecate Status"),
    io:format("~n"),
    
    %% Identity
    case hecate_identity:get_mri() of
        {ok, MRI} ->
            print_section("Identity"),
            print_kv("MRI", binary_to_list(MRI)),
            case hecate_identity:get_public_key() of
                {ok, PubKey} -> print_kv("Public Key", truncate_key(PubKey));
                _ -> ok
            end;
        not_initialized ->
            print_kv("Identity", ?YELLOW ++ "Not initialized" ++ ?RESET)
    end,
    
    io:format("~n"),
    
    %% Auth status
    print_section("Authentication"),
    case hecate_store:get(<<"auth">>, <<"org_identity">>) of
        {ok, OrgId} ->
            print_kv("Organization", binary_to_list(OrgId)),
            print_kv("Status", ?GREEN ++ ?ICON_CHECK ++ " Joined" ++ ?RESET);
        _ ->
            print_kv("Status", ?YELLOW ++ ?ICON_WAIT ++ " Not joined" ++ ?RESET)
    end,

    io:format("~n"),

    %% Join status
    JoinStatus = hecate_realm_session:get_status(),
    case maps:get(status, JoinStatus, idle) of
        joining ->
            print_section("Joining"),
            print_kv("Status", ?CYAN ++ "In progress — log in via browser" ++ ?RESET);
        _ -> ok
    end,
    
    io:format("~n").

watch_status() ->
    io:format("\e[?25l"), %% Hide cursor
    watch_loop(),
    io:format("\e[?25h"). %% Show cursor

watch_loop() ->
    io:format("\e[2J\e[H"), %% Clear and home
    show_status_once(),
    print_dim("Press Ctrl+C to exit"),
    timer:sleep(2000),
    watch_loop().

%%%===================================================================
%%% QR Code Generation
%%%===================================================================

generate_qr(Url) when is_binary(Url) ->
    generate_qr(binary_to_list(Url));
generate_qr(Url) ->
    try
        QR = qrcode:encode(Url),
        {_, _, Matrix} = QR,
        render_qr_matrix(Matrix)
    catch
        _:_ ->
            %% Fallback if qrcode lib fails
            ["(QR code unavailable)", "", "Visit the URL below"]
    end.

render_qr_matrix(Matrix) ->
    %% Convert matrix to block characters
    %% Use Unicode block elements for compact display
    Rows = tuple_to_list(Matrix),
    render_qr_rows(Rows, []).

render_qr_rows([], Acc) ->
    lists:reverse(Acc);
render_qr_rows([Row], Acc) ->
    %% Odd row at end - render with spaces below
    Line = render_qr_single_row(Row),
    render_qr_rows([], [Line | Acc]);
render_qr_rows([Row1, Row2 | Rest], Acc) ->
    %% Combine two rows into one line using block chars
    Line = render_qr_row_pair(Row1, Row2),
    render_qr_rows(Rest, [Line | Acc]).

render_qr_single_row(Row) ->
    Cells = tuple_to_list(Row),
    lists:map(fun
        (1) -> "▀";  %% Upper half block
        (_) -> " "
    end, Cells).

render_qr_row_pair(Row1, Row2) ->
    Cells1 = tuple_to_list(Row1),
    Cells2 = tuple_to_list(Row2),
    Pairs = lists:zip(Cells1, Cells2),
    lists:map(fun
        ({1, 1}) -> "█";  %% Full block
        ({1, 0}) -> "▀";  %% Upper half
        ({0, 1}) -> "▄";  %% Lower half
        ({0, 0}) -> " "   %% Empty
    end, Pairs).

%%%===================================================================
%%% Box Drawing
%%%===================================================================

print_box_line(top, Width) ->
    io:format("~s~s~s~n", [?TOP_LEFT, lists:duplicate(Width, ?HORIZONTAL), ?TOP_RIGHT]);
print_box_line(bottom, Width) ->
    io:format("~s~s~s~n", [?BOT_LEFT, lists:duplicate(Width, ?HORIZONTAL), ?BOT_RIGHT]).

print_box_separator(Width) ->
    io:format("~s~s~s~n", [?VERTICAL, lists:duplicate(Width, ?HORIZONTAL), ?VERTICAL]).

print_box_content(Width, Content) ->
    %% Strip ANSI codes for length calculation
    VisibleLen = visible_length(Content),
    Padding = Width - VisibleLen,
    LeftPad = Padding div 2,
    RightPad = Padding - LeftPad,
    io:format("~s~s~s~s~s~n", [
        ?VERTICAL,
        lists:duplicate(LeftPad, $\s),
        Content,
        lists:duplicate(RightPad, $\s),
        ?VERTICAL
    ]).

visible_length(Str) ->
    %% Remove ANSI escape sequences for length calculation
    Clean = re:replace(Str, "\e\\[[0-9;]*m", "", [global, {return, list}]),
    string:length(Clean).

center_text(Text, Width) ->
    Len = visible_length(Text),
    case Len >= Width of
        true -> Text;
        false ->
            Pad = Width - Len,
            Left = Pad div 2,
            Right = Pad - Left,
            lists:duplicate(Left, $\s) ++ Text ++ lists:duplicate(Right, $\s)
    end.

%%%===================================================================
%%% Output Helpers
%%%===================================================================

print_header(Title) ->
    io:format("~n~s~s~s~n", [?BOLD, Title, ?RESET]),
    io:format("~s~n", [lists:duplicate(40, $─)]).

print_section(Title) ->
    io:format("~s~s~s~n", [?BOLD ++ ?CYAN, Title, ?RESET]).

print_kv(Key, Value) ->
    io:format("  ~s~s~s: ~s~n", [?DIM, Key, ?RESET, Value]).

print_success(Msg) ->
    io:format("~s~s ~s~s~n", [?GREEN, ?ICON_CHECK, Msg, ?RESET]).

print_error(Msg) ->
    io:format("~s~s ~s~s~n", [?RED, ?ICON_CROSS, Msg, ?RESET]).

print_warning(Msg) ->
    io:format("~s! ~s~s~n", [?YELLOW, Msg, ?RESET]).

print_info(Msg) ->
    io:format("~s~s ~s~s~n", [?CYAN, ?ICON_ARROW, Msg, ?RESET]).

print_dim(Msg) ->
    io:format("~s~s~s~n", [?DIM, Msg, ?RESET]).

truncate_key(Key) when is_binary(Key) ->
    B64 = base64:encode(Key),
    case byte_size(B64) > 20 of
        true ->
            <<Prefix:16/binary, _/binary>> = B64,
            binary_to_list(Prefix) ++ "...";
        false ->
            binary_to_list(B64)
    end.

show_usage() ->
    io:format("~n~s~shecate~s - The Macula mesh agent~n~n", [?BOLD, ?CYAN, ?RESET]),
    io:format("~sUSAGE:~s~n", [?BOLD, ?RESET]),
    io:format("    hecate <command> [options]~n~n"),
    io:format("~sCOMMANDS:~s~n", [?BOLD, ?RESET]),
    io:format("    ~sinit~s       Initialize agent identity~n", [?CYAN, ?RESET]),
    io:format("    ~sjoin~s       Join a Realm (OAuth flow)~n", [?CYAN, ?RESET]),
    io:format("    ~sstatus~s     Show current status (-w for watch mode)~n", [?CYAN, ?RESET]),
    io:format("    ~sstart~s      Start the daemon~n", [?CYAN, ?RESET]),
    io:format("    ~sstop~s       Stop the daemon~n", [?CYAN, ?RESET]),
    io:format("    ~sversion~s    Show version~n", [?CYAN, ?RESET]),
    io:format("    ~shelp~s       Show this help~n", [?CYAN, ?RESET]),
    io:format("~n"),
    io:format("~sSUPPORT:~s~n", [?BOLD, ?RESET]),
    io:format("    ☕ Buy Me a Coffee: ~s~shttps://buymeacoffee.com/rlefever~s~n~n", [?CYAN, ?BOLD, ?RESET]).

show_version() ->
    Vsn = case application:get_key(hecate, vsn) of
        {ok, V} -> V;
        undefined -> "0.1.0"
    end,
    io:format("~shecate~s ~s~n", [?BOLD, ?RESET, Vsn]).

ensure_started() ->
    %% Start required apps in order
    _ = application:ensure_all_started(crypto),
    _ = application:ensure_all_started(ssl),
    _ = application:ensure_all_started(hackney),
    _ = application:ensure_all_started(jsx),
    _ = ok,
    _ = application:ensure_all_started(esqlite),
    
    %% Try to start hecate (may fail in escript if some deps missing)
    case application:ensure_all_started(hecate) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok;
        {error, Reason} ->
            %% Log but continue - some commands might work anyway
            io:format(?DIM ++ "Note: Some features may be unavailable (~p)~n" ++ ?RESET, [Reason]),
            ok
    end.
