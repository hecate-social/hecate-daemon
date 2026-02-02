-module(social_aggregate).

-export([new/1, apply_event/2]).

-record(social_aggregate, {
    agent_identity :: binary(),
    following :: [binary()],
    followers :: [binary()],
    endorsements_given :: [binary()],
    endorsements_received :: [binary()]
}).

-opaque social_aggregate() :: #social_aggregate{}.
-export_type([social_aggregate/0]).

-spec new(binary()) -> social_aggregate().
new(AgentIdentity) ->
    #social_aggregate{
        agent_identity = AgentIdentity,
        following = [],
        followers = [],
        endorsements_given = [],
        endorsements_received = []
    }.

-spec apply_event(social_aggregate(), map()) -> social_aggregate().
apply_event(#social_aggregate{} = Agg, #{<<"event_type">> := <<"agent_followed_v1">>, <<"follower_identity">> := Follower, <<"followed_identity">> := Followed}) ->
    case Agg#social_aggregate.agent_identity of
        Follower -> Agg#social_aggregate{following = [Followed | Agg#social_aggregate.following]};
        Followed -> Agg#social_aggregate{followers = [Follower | Agg#social_aggregate.followers]};
        _ -> Agg
    end;
apply_event(#social_aggregate{} = Agg, #{<<"event_type">> := <<"agent_unfollowed_v1">>, <<"follower_identity">> := Follower, <<"followed_identity">> := Followed}) ->
    case Agg#social_aggregate.agent_identity of
        Follower -> Agg#social_aggregate{following = lists:delete(Followed, Agg#social_aggregate.following)};
        Followed -> Agg#social_aggregate{followers = lists:delete(Follower, Agg#social_aggregate.followers)};
        _ -> Agg
    end;
apply_event(#social_aggregate{} = Agg, #{<<"event_type">> := <<"capability_endorsed_v1">>, <<"endorser_identity">> := Endorser, <<"capability_mri">> := MRI}) ->
    case Agg#social_aggregate.agent_identity of
        Endorser -> Agg#social_aggregate{endorsements_given = [MRI | Agg#social_aggregate.endorsements_given]};
        _ -> Agg#social_aggregate{endorsements_received = [MRI | Agg#social_aggregate.endorsements_received]}
    end;
apply_event(#social_aggregate{} = Agg, #{<<"event_type">> := <<"endorsement_revoked_v1">>, <<"endorser_identity">> := Endorser, <<"capability_mri">> := MRI}) ->
    case Agg#social_aggregate.agent_identity of
        Endorser -> Agg#social_aggregate{endorsements_given = lists:delete(MRI, Agg#social_aggregate.endorsements_given)};
        _ -> Agg#social_aggregate{endorsements_received = lists:delete(MRI, Agg#social_aggregate.endorsements_received)}
    end;
apply_event(Agg, _) -> Agg.
