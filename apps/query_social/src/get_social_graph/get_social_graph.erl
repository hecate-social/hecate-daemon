%%% @doc Query: Get complete social graph for an agent
%%% Returns following, followers, endorsements given, and endorsements received.
-module(get_social_graph).

-export([execute/1, execute/2]).

%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [execute/1]}).

%% @doc Get complete social graph for a given agent.
%% Always succeeds - errors are handled internally by returning empty lists.
-spec execute(binary()) -> {ok, map()}.
execute(AgentIdentity) ->
    execute(AgentIdentity, #{}).

%% @doc Get social graph with options.
%% Options:
%%   - include_following: boolean (default: true)
%%   - include_followers: boolean (default: true)
%%   - include_endorsements_given: boolean (default: true)
%%   - include_endorsements_received: boolean (default: true)
%%   - limit_per_section: integer (default: 100)
%% Always succeeds - errors are handled internally by returning empty lists.
-spec execute(binary(), map()) -> {ok, map()}.
execute(AgentIdentity, Opts) ->
    Limit = maps:get(limit_per_section, Opts, 100),

    Result = #{
        agent_identity => AgentIdentity
    },

    %% Get following (people this agent follows)
    Result1 = case maps:get(include_following, Opts, true) of
        true -> Result#{following => get_following_list(AgentIdentity, Limit)};
        false -> Result
    end,

    %% Get followers (people who follow this agent)
    Result2 = case maps:get(include_followers, Opts, true) of
        true -> Result1#{followers => get_followers_list(AgentIdentity, Limit)};
        false -> Result1
    end,

    %% Get endorsements given by this agent
    Result3 = case maps:get(include_endorsements_given, Opts, true) of
        true -> Result2#{endorsements_given => get_endorsements_given(AgentIdentity, Limit)};
        false -> Result2
    end,

    %% Get endorsements received (endorsements of this agent's capabilities)
    Result4 = case maps:get(include_endorsements_received, Opts, true) of
        true -> Result3#{endorsements_received => get_endorsements_received(AgentIdentity, Limit)};
        false -> Result3
    end,

    %% Add summary counts
    FinalResult = add_summary(Result4),

    {ok, FinalResult}.

%% Internal functions

get_following_list(AgentIdentity, Limit) ->
    Sql = io_lib:format(
        "SELECT followed_identity, followed_at "
        "FROM followers "
        "WHERE follower_identity = '~s' "
        "ORDER BY followed_at DESC "
        "LIMIT ~B",
        [escape_sql(AgentIdentity), Limit]
    ),

    case query_social_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            [#{
                identity => FollowedIdentity,
                followed_at => FollowedAt
            } || [FollowedIdentity, FollowedAt] <- Rows];
        {error, _} ->
            []
    end.

get_followers_list(AgentIdentity, Limit) ->
    Sql = io_lib:format(
        "SELECT follower_identity, followed_at "
        "FROM followers "
        "WHERE followed_identity = '~s' "
        "ORDER BY followed_at DESC "
        "LIMIT ~B",
        [escape_sql(AgentIdentity), Limit]
    ),

    case query_social_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            [#{
                identity => FollowerIdentity,
                followed_at => FollowedAt
            } || [FollowerIdentity, FollowedAt] <- Rows];
        {error, _} ->
            []
    end.

get_endorsements_given(AgentIdentity, Limit) ->
    Sql = io_lib:format(
        "SELECT capability_mri, comment, endorsed_at "
        "FROM endorsements "
        "WHERE endorser_identity = '~s' AND revoked_at IS NULL "
        "ORDER BY endorsed_at DESC "
        "LIMIT ~B",
        [escape_sql(AgentIdentity), Limit]
    ),

    case query_social_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            [#{
                capability_mri => MRI,
                comment => Comment,
                endorsed_at => EndorsedAt
            } || [MRI, Comment, EndorsedAt] <- Rows];
        {error, _} ->
            []
    end.

get_endorsements_received(_AgentIdentity, Limit) ->
    %% Get endorsements from 'my_endorsements' table where my_capability_mri
    %% belongs to this agent. This requires joining with capabilities table
    %% or we need to extract agent from MRI pattern.
    %% For now, we query my_endorsements directly (assuming the capability owner
    %% matches the agent identity in our MY_IDENTITIES config).
    %% TODO: Filter by AgentIdentity once we have a way to link capabilities to owners
    Sql = io_lib:format(
        "SELECT endorser_identity, my_capability_mri, comment, endorsed_at "
        "FROM my_endorsements "
        "WHERE revoked_at IS NULL "
        "ORDER BY endorsed_at DESC "
        "LIMIT ~B",
        [Limit]
    ),

    case query_social_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            [#{
                endorser_identity => Endorser,
                capability_mri => MRI,
                comment => Comment,
                endorsed_at => EndorsedAt
            } || [Endorser, MRI, Comment, EndorsedAt] <- Rows];
        {error, _} ->
            []
    end.

add_summary(Result) ->
    Following = maps:get(following, Result, []),
    Followers = maps:get(followers, Result, []),
    GivenEndorsements = maps:get(endorsements_given, Result, []),
    ReceivedEndorsements = maps:get(endorsements_received, Result, []),

    Result#{
        summary => #{
            following_count => length(Following),
            followers_count => length(Followers),
            endorsements_given_count => length(GivenEndorsements),
            endorsements_received_count => length(ReceivedEndorsements)
        }
    }.

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
