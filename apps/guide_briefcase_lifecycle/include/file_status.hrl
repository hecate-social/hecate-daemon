%%% @doc File status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(FILE_INITIATED, 1).   %% File has been registered or imported
-define(FILE_RENAMED,   2).   %% File has been renamed at least once
-define(FILE_MOVED,     4).   %% File has been moved at least once
-define(FILE_ARCHIVED,  8).   %% File has been archived
-define(FILE_STARRED,  16).   %% File is starred
-define(FILE_IMPORTED, 32).   %% File was imported (has blob)

-define(FILE_FLAG_MAP, #{
    1  => <<"Initiated">>,
    2  => <<"Renamed">>,
    4  => <<"Moved">>,
    8  => <<"Archived">>,
    16 => <<"Starred">>,
    32 => <<"Imported">>
}).
