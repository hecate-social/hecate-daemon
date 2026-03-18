%%% @doc Folder status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(FOLDER_INITIATED, 1).  %% Folder has been created
-define(FOLDER_RENAMED,   2).  %% Folder has been renamed at least once
-define(FOLDER_MOVED,     4).  %% Folder has been moved at least once
-define(FOLDER_ARCHIVED,  8).  %% Folder has been archived

-define(FOLDER_FLAG_MAP, #{
    1 => <<"Initiated">>,
    2 => <<"Renamed">>,
    4 => <<"Moved">>,
    8 => <<"Archived">>
}).
