module View exposing (view)

import SoundFont.Msg exposing (..)
import Model exposing (Model, Track)
import Styles
import Dict exposing (Dict)
import Html exposing (Html, Attribute, text, div, input, button, table, tr, td, select, option, node, h1, p)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onCheck, onInput, targetValue)
import SoundFont.Types exposing (..)
import MidiTable
import Json.Decode as JD exposing ((:=))
import String
import Array exposing (Array)
import Material.Scheme
import Material.Layout as Layout
import Material.Color as Color
import Material.Button as Button
import Material.Textfield as Textfield
import Material.Menu as Menu
import Material.Dialog as Dialog
import Material.Options as Options


view : Model -> Html Msg
view model =
    Material.Scheme.topWithScheme Color.Teal Color.LightGreen <|
        Layout.render Mdl
            model.mdl
            [ Layout.fixedHeader
            ]
            { header = [ viewHeader model ]
            , drawer = []
            , tabs = ( [], [] )
            , main = [ viewBody model ]
            }


viewHeader : Model -> Html Msg
viewHeader model =
    Layout.row
        []
        [ Layout.title [] [ text "Colluder" ]
        , Layout.spacer
        , Layout.navigation []
            [ Layout.link
                [ Layout.href "https://github.com/knewter/colluder" ]
                [ text "github" ]
            ]
        ]


viewBody : Model -> Html Msg
viewBody model =
    let
        compiled =
            Styles.compile Styles.css
    in
        div [ style [ ( "padding", "6rem" ) ] ]
            [ node "style" [ type' "text/css" ] [ text compiled.css ]
            , viewMetadata model
            , viewTopControls model
            , viewSongEditor model
            , viewDialog model
            ]


viewDialog : Model -> Html Msg
viewDialog model =
    case model.trackBeingEdited of
        Nothing ->
            viewAbout model

        Just trackId ->
            viewTrackNoteChooser model trackId


viewTrackNoteChooser : Model -> Int -> Html Msg
viewTrackNoteChooser model trackId =
    let
        noteIdPrefix =
            130

        octaveIdPrefix =
            230

        noteButton : Int -> String -> Html Msg
        noteButton noteNum note =
            Button.render Mdl
                [ noteIdPrefix + noteNum ]
                model.mdl
                [ Options.css "width" "2rem"
                , Button.onClick (ChooseNote note)
                ]
                [ text note ]

        octaveButton : Int -> Int -> Html Msg
        octaveButton octaveNum octave =
            Button.render Mdl
                [ octaveIdPrefix + octaveNum ]
                model.mdl
                [ Options.css "width" "2rem"
                , Dialog.closeOn "click"
                , Button.onClick (ChooseOctave octave)
                ]
                [ text <| toString octave ]

        octaveButtons : Array (Html Msg)
        octaveButtons =
            MidiTable.octaves
                |> Array.indexedMap octaveButton

        noteButtons : Array (Html Msg)
        noteButtons =
            MidiTable.notes
                |> Array.indexedMap noteButton
    in
        case model.chosenNote of
            Nothing ->
                Dialog.view []
                    [ Dialog.title [] [ text "Pick the Note" ]
                    , Dialog.content []
                        (noteButtons
                            |> Array.toList
                        )
                    , Dialog.actions []
                        [ Button.render Mdl
                            [ 5 ]
                            model.mdl
                            [ Dialog.closeOn "click" ]
                            [ text "Close" ]
                        ]
                    ]

            Just _ ->
                Dialog.view []
                    [ Dialog.title [] [ text "Pick the Octave" ]
                    , Dialog.content []
                        (octaveButtons
                            |> Array.toList
                        )
                    , Dialog.actions []
                        [ Button.render Mdl
                            [ 6 ]
                            model.mdl
                            [ Dialog.closeOn "click" ]
                            [ text "Close" ]
                        ]
                    ]


viewAbout : Model -> Html Msg
viewAbout model =
    Dialog.view []
        [ Dialog.title [] [ text "About" ]
        , Dialog.content []
            [ p [] [ text "This is a music toy" ]
            ]
        , Dialog.actions []
            [ Button.render Mdl
                [ 3 ]
                model.mdl
                [ Dialog.closeOn "click" ]
                [ text "Close" ]
            ]
        ]


viewTopControls : Model -> Html Msg
viewTopControls model =
    let
        { id } =
            Styles.mainNamespace

        pauseText =
            case model.paused of
                True ->
                    "unpause"

                False ->
                    "pause"
    in
        div []
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                [ Button.onClick TogglePaused ]
                [ text pauseText ]
            , Textfield.render Mdl
                [ 1 ]
                model.mdl
                [ Textfield.onInput (SetBPM << Result.withDefault 128 << String.toInt)
                , Textfield.floatingLabel
                , Textfield.label "BPM"
                , Textfield.value (toString model.bpm)
                ]
            ]


viewMetadata : Model -> Html Msg
viewMetadata model =
    div []
        [ div [] [ text <| "Current note: " ++ (toString model.currentNote) ]
        , div [] [ text <| "Paused: " ++ (toString model.paused) ]
        ]


viewSongEditor : Model -> Html Msg
viewSongEditor model =
    let
        trackRows =
            model.song
                |> Dict.foldl (\trackId track acc -> acc ++ [ (viewTrack model trackId track) ]) []

        { class } =
            Styles.mainNamespace
    in
        div [ class [ Styles.Song ] ]
            [ table [] trackRows
            , Button.render Mdl
                [ 2 ]
                model.mdl
                [ Button.onClick AddTrack ]
                [ text "Add Track" ]
            ]


viewTrackCell : Int -> Int -> ( Int, Bool ) -> Html Msg
viewTrackCell currentNote trackId ( slotId, on ) =
    let
        { classList } =
            Styles.mainNamespace

        isCurrentNote =
            slotId == currentNote
    in
        td
            [ classList [ ( Styles.CurrentNote, isCurrentNote ), ( Styles.Checked, on ) ] ]
            [ input
                [ type' "checkbox", checked on, onCheck (CheckNote trackId slotId) ]
                [ text <| toString slotId ]
            ]


viewTrack : Model -> Int -> Track -> Html Msg
viewTrack model trackId track =
    let
        trackCells =
            track.slots
                |> Dict.toList
                |> List.map (viewTrackCell model.currentNote trackId)

        { class } =
            Styles.mainNamespace
    in
        tr [ class [ Styles.Track ] ]
            ([ td [] [ viewTrackMetadata model trackId track ] ]
                ++ trackCells
            )


onChange : (Int -> Msg) -> Html.Attribute Msg
onChange tagger =
    on "change" <|
        (JD.at [ "target", "selectedIndex" ] JD.int)
            `JD.andThen` (JD.succeed << tagger)


viewTrackMetadata : Model -> Int -> Track -> Html Msg
viewTrackMetadata model trackId track =
    let
        setNote : Int -> Msg
        setNote noteId =
            SetNote trackId (MidiNote noteId 0.0 1.0)

        midiNotesStartingPoint : Int
        midiNotesStartingPoint =
            300

        menuItems : List (Menu.Item Msg)
        menuItems =
            (MidiTable.notesOctaves
                |> Dict.toList
                |> List.map
                    --(viewNoteOption trackId track)
                    (\( k, ( note, octave ) ) ->
                        (Menu.item
                            [ Menu.onSelect (setNote k) ]
                            [ text (noteText ( note, octave )) ]
                        )
                    )
            )
    in
        case MidiTable.getNoteAndOctaveByNoteId track.note.id of
            Nothing ->
                text ""

            Just ( note, octave ) ->
                Button.render Mdl
                    [ 4 ]
                    model.mdl
                    [ Dialog.openOn "click"
                    , Button.onClick <| SetEditingTrack trackId
                    ]
                    [ text <| note ++ (toString octave) ]



-- Menu.render Mdl
--     [ midiNotesStartingPoint + trackId ]
--     model.mdl
--     [ Menu.ripple, Menu.bottomLeft ]
--     menuItems
-- select [ onChange setNote ]
--     (MidiTable.notesOctaves
--         |> Dict.toList
--         |> List.map (viewNoteOption trackId track)
--     )


viewNoteOption : Int -> Track -> ( Int, ( String, Int ) ) -> Html Msg
viewNoteOption trackId track ( noteId, ( note, octave ) ) =
    option [ value <| toString noteId, selected (noteId == track.note.id) ]
        [ text <| (noteText ( note, octave )) ]


noteText : ( String, Int ) -> String
noteText ( note, octave ) =
    note ++ " (" ++ (toString octave) ++ ")"
