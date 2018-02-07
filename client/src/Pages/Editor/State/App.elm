module Pages.Editor.State.App
    exposing
        ( Model(..)
        , Msg(..)
        , init
        , subscriptions
        , update
        )

import Data.Entity as Entity exposing (Entity(..))
import Data.Jwt as Jwt exposing (Jwt)
import Data.Transition as Transition exposing (Transition(..))
import Ellie.Types.Revision as Revision exposing (Revision)
import Ellie.Types.Workspace as Workspace exposing (Workspace)
import Elm.Package as Package exposing (Package)
import Pages.Editor.Effects.Inbound as Inbound exposing (Inbound)
import Pages.Editor.Effects.Outbound as Outbound exposing (Outbound)
import Pages.Editor.Flags as Flags exposing (Flags)
import Pages.Editor.Route as Route exposing (Route(..))
import Pages.Editor.State.Setup as Setup
import Pages.Editor.State.Working as Working


type Model
    = Initial Flags Route
    | Setup Setup.Model
    | Working Working.Model
    | Broken


init : Flags -> Route -> ( Model, Outbound Msg )
init flags route =
    case route of
        Route.New ->
            Setup.init flags.token Nothing
                |> Tuple.mapFirst Setup
                |> Tuple.mapSecond (Outbound.map SetupMsg)

        Route.Existing revisionId ->
            Setup.init flags.token (Just revisionId)
                |> Tuple.mapFirst Setup
                |> Tuple.mapSecond (Outbound.map SetupMsg)

        NotFound ->
            ( Initial flags route
            , Outbound.Redirect <| Route.toString Route.New
            )


setupToWorking :
    { token : Jwt
    , revision : Maybe (Entity Revision.Id Revision)
    , packages : List Package
    }
    -> Model
setupToWorking { token, revision, packages } =
    Working <| Working.init token revision packages


type Msg
    = NoOp
    | AppStart
    | RouteChanged Route
    | SetupMsg Setup.Msg
    | WorkingMsg Working.Msg
    | ErrorOccured String


update : Msg -> Model -> ( Model, Outbound Msg )
update msg_ model =
    case ( model, msg_ ) of
        ( _, RouteChanged route ) ->
            case model of
                Initial flags _ ->
                    init flags route

                Setup setupState ->
                    update (SetupMsg (Setup.RouteChanged route)) model

                _ ->
                    ( model, Outbound.none )

        ( Setup setupState, SetupMsg msg ) ->
            Setup.update msg setupState
                |> Tuple.mapFirst (Transition.fold Setup setupToWorking)
                |> Tuple.mapSecond (Outbound.map SetupMsg)

        ( Working workingState, WorkingMsg msg ) ->
            Working.update msg workingState
                |> Tuple.mapFirst Working
                |> Tuple.mapSecond (Outbound.map WorkingMsg)

        _ ->
            ( model, Outbound.none )


subscriptions : Model -> Inbound Msg
subscriptions state =
    case state of
        Setup setupState ->
            Inbound.map SetupMsg <| Setup.subscriptions setupState

        Working workingState ->
            Working.subscriptions workingState

        _ ->
            Inbound.none
