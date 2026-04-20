%%% @doc Bit flags for repo lifecycle status.
%%%
%%% Use with evoq_bit_flags for status manipulation.
%%% Powers of two — each flag gets a unique bit position.
%%% @end

-define(REPO_INITIATED,       1).    %% 2^0
-define(REPO_RENAMED,         2).    %% 2^1
-define(REPO_DESCRIPTION_SET, 4).    %% 2^2
-define(REPO_ARCHIVED,        8).    %% 2^3
-define(REPO_PUBLIC,         16).    %% 2^4  (visibility)
