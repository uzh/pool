open Tyxml.Html

let session_reminder_text_element_help language ?session () =
  let session_overview_preview =
    match session with
    | Some session ->
      Session.to_email_text language session
      |> Http_utils.add_line_breaks
      |> CCList.pure
      |> div
    | None -> div [] (* TODO[timhub]: create some dummy session? *)
  in
  let open Pool_common.Language in
  let name_hint = function
    | En -> "first and last name"
    | De -> "Vor- und Nachname"
  in
  let session_overview_hint = function
    | En -> "displays start, duration and location of the session"
    | De -> "Zeigt Startzeit, Dauer und Location der Session"
  in
  let wrap_hints html =
    div
      ~a:[ a_class [ "flexcolumn" ] ]
      [ p
          [ txt
              Pool_common.(
                Utils.hint_to_string language I18n.TemplateTextElementsHint)
          ]
      ; html
      ]
  in
  [ "name", name_hint, div [ txt "John Doe" ]
  ; "sessionOverview", session_overview_hint, session_overview_preview
  ]
  |> CCList.map (fun (elm, hint, example) ->
         [ txt (Format.asprintf "{%s}" elm); txt (hint language); example ])
  |> Component_table.horizontal_table `Simple language ~align_top:true
  |> wrap_hints
;;

let mail_to_html ?(highlight_first_line = true) mail =
  let open Pool_location.Address.Mail in
  let { institution; room; building; street; zip; city } = mail in
  let building_room =
    match building with
    | Some building ->
      Format.asprintf "%s %s" (room |> Room.value) (building |> Building.value)
    | None -> room |> Room.value
  in
  let city_zip =
    Format.asprintf "%s %s" (city |> City.value) (zip |> Zip.value)
  in
  let base = [ building_room; street |> Street.value; city_zip ] in
  (match institution with
  | Some institution -> CCList.cons (institution |> Institution.value) base
  | None -> base)
  |> CCList.foldi
       (fun html index str ->
         let str = str |> txt in
         match index with
         | 0 ->
           CCList.pure (if highlight_first_line then strong [ str ] else str)
         | _ -> html @ [ br (); str ])
       []
  |> span
;;

let address_to_html
    ?(highlight_first_line = true)
    language
    (location_address : Pool_location.Address.t)
  =
  let open Pool_location.Address in
  match location_address with
  | Virtual ->
    [ txt
        (Pool_common.(
           Utils.field_to_string language Pool_common.Message.Field.Virtual)
        |> CCString.capitalize_ascii)
    ]
    |> fun html ->
    (match highlight_first_line with
    | true -> strong html
    | false -> span html)
  | Physical mail -> mail_to_html ~highlight_first_line mail
;;

let location_to_html ?(public = false) language (location : Pool_location.t) =
  let open Pool_location in
  let title =
    [ strong [ txt (location.name |> Name.show) ] ] |> p |> CCOption.pure
  in
  let address =
    [ address_to_html ~highlight_first_line:false language location.address ]
    |> p
    |> CCOption.pure
  in
  let status =
    match public with
    | true -> None
    | false ->
      [ span
          [ txt
              (Format.asprintf
                 "%s: %s"
                 (Pool_common.(
                    Utils.field_to_string language Message.Field.Status)
                 |> CCString.capitalize_ascii)
                 (location.status |> Status.show))
          ]
      ]
      |> p
      |> CCOption.pure
  in
  let link =
    CCOption.map
      (fun l ->
        p
          [ a
              ~a:[ a_href (l |> Link.value); a_target "_blank" ]
              [ txt (l |> Link.value) ]
          ])
      location.link
  in
  [ title; address; status; link ]
  |> CCList.filter_map CCFun.id
  |> div ~a:[ a_class [ "stack-sm" ] ]
;;
