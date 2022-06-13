open Tyxml.Html
open Component
module Message = Pool_common.Message

let mailing_title (s : Mailing.t) =
  Pool_common.I18n.MailingDetailTitle
    (s.Mailing.start_at |> Mailing.StartAt.value)
;;

let mailings_path ?(suffix = "") experiment_id =
  Format.asprintf
    "/admin/experiments/%s/mailings/%s"
    (Pool_common.Id.value experiment_id)
    suffix
  |> Sihl.Web.externalize_path
;;

let detail_mailing_path ?(suffix = "") experiment_id mailing =
  let open Mailing in
  Format.asprintf
    "%s/%s"
    (mailings_path ~suffix:(Id.value mailing.id) experiment_id)
    suffix
;;

module List = struct
  let thead language =
    let open Pool_common in
    Message.Field.[ Some Start; Some End; Some Rate; None; None; None ]
    |> CCList.map (fun field ->
           th
             [ txt
                 (CCOption.map_or
                    ~default:""
                    (fun f -> Utils.field_to_string_capitalized language f)
                    field)
             ])
    |> tr
    |> CCList.pure
    |> thead
  ;;

  let row Pool_context.{ csrf; language; _ } experiment_id (mailing : Mailing.t)
    =
    let open Mailing in
    tr
      [ td [ mailing.start_at |> StartAt.to_human |> txt ]
      ; td [ mailing.end_at |> EndAt.to_human |> txt ]
      ; td [ mailing.rate |> Rate.value |> CCInt.to_string |> txt ]
      ; td
          [ a
              ~a:[ detail_mailing_path experiment_id mailing |> a_href ]
              [ txt
                  Pool_common.(Utils.control_to_string language Message.(More))
              ]
          ]
      ; td
          [ form
              ~a:
                [ a_method `Post
                ; a_action
                    (detail_mailing_path ~suffix:"stop" experiment_id mailing)
                ]
              [ Component.csrf_element csrf ()
              ; submit_element language Message.(Stop None) ()
              ]
          ]
      ; td
          [ form
              ~a:
                [ a_method `Post
                ; a_action
                    (detail_mailing_path ~suffix:"delete" experiment_id mailing)
                ]
              [ Component.csrf_element csrf ()
              ; submit_element
                  language
                  Message.(Delete None)
                  ~submit_type:`Error
                  ()
              ]
          ]
      ]
  ;;

  let create (Pool_context.{ language; _ } as context) experiment mailings =
    table
      ~thead:(thead language)
      ~a:[ a_class [ "striped" ] ]
      (CCList.map (row context experiment) mailings)
  ;;
end

let index (Pool_context.{ language; _ } as context) experiment mailings =
  let experiment_id = experiment.Experiment.id in
  let open Pool_common in
  let html =
    div
      ~a:[ a_class [ "stack-lg" ] ]
      [ (if CCList.is_empty mailings
        then
          div
            [ p
                [ I18n.EmtpyList Message.Field.Mailing
                  |> Utils.text_to_string language
                  |> txt
                ]
            ; a
                ~a:[ a_href (mailings_path ~suffix:"create" experiment_id) ]
                [ Utils.text_to_string language I18n.MailingNewTitle |> txt ]
            ]
        else List.create context experiment_id mailings)
      ]
  in
  Page_admin_experiments.experiment_layout
    language
    (Page_admin_experiments.NavLink I18n.Mailings)
    experiment.Experiment.id
    ~active:I18n.Mailings
    html
;;

let detail Pool_context.{ language; _ } experiment_id (mailing : Mailing.t) =
  let open Mailing in
  let mailing_overview =
    div
      ~a:[ a_class [ "stack" ] ]
      [ (* TODO [aerben] use better formatted date *)
        (let rows =
           let open Message in
           [ Field.Start, mailing.start_at |> StartAt.to_human
           ; Field.End, mailing.end_at |> EndAt.to_human
           ; Field.Rate, mailing.rate |> Rate.value |> CCInt.to_string
           ; ( Field.Distribution
             , mailing.distribution
               |> CCOption.map_or ~default:"" Mailing.Distribution.show )
           ]
           |> CCList.map (fun (field, value) ->
                  tr
                    [ th
                        [ txt
                            (field
                            |> Pool_common.Utils.field_to_string language
                            |> CCString.capitalize_ascii)
                        ]
                    ; td [ txt value ]
                    ])
         in
         table ~a:[ a_class [ "striped" ] ] rows)
      ; p
          [ a
              ~a:
                [ detail_mailing_path ~suffix:"edit" experiment_id mailing
                  |> a_href
                ]
              [ Message.(Edit (Some Field.Mailing))
                |> Pool_common.Utils.control_to_string language
                |> txt
              ]
          ]
      ]
  in
  let html = div ~a:[ a_class [ "stack-lg" ] ] [ mailing_overview ] in
  Page_admin_experiments.experiment_layout
    language
    (Page_admin_experiments.I18n (mailing_title mailing))
    experiment_id
    html
;;

let form
    ?(mailing : Mailing.t option)
    Pool_context.{ language; csrf; _ }
    experiment_id
    flash_fetcher
  =
  let functions =
    {js|
      var container = document.getElementById('mailings');
      container.addEventListener('htmx:beforeRequest', (e) => {
        var start = container.querySelector("[name='start']").value;
        var end = container.querySelector("[name='end']").value;

        if ((!start || !end) || Date.parse(start) > Date.parse(end)) {
          e.preventDefault();
          };
      });
  |js}
  in
  let heading, action, submit =
    match mailing with
    | None ->
      let text = Message.(Create (Some Field.Mailing)) in
      ( text |> Pool_common.Utils.control_to_string language
      , mailings_path experiment_id
      , text )
    | Some m ->
      ( m |> mailing_title |> Pool_common.Utils.text_to_string language
      , m |> detail_mailing_path experiment_id
      , Message.(Edit (Some Field.Mailing)) )
  in
  let html =
    let open Htmx in
    div
      [ h1 ~a:[ a_class [ "heading-2" ] ] [ txt heading ]
      ; form
          ~a:
            [ a_class [ "stack" ]
            ; a_method `Post
            ; a_action (action |> Sihl.Web.externalize_path)
            ]
          [ Component.csrf_element csrf ()
          ; div
              ~a:
                [ a_id "mailings"
                ; a_class [ "stack" ]
                ; hx_target "#overlaps"
                ; hx_trigger "change"
                ; hx_swap "innerHTML"
                ; hx_post (mailings_path ~suffix:"search-info" experiment_id)
                ]
              [ input_element
                  ?value:
                    (CCOption.map
                       (fun (m : Mailing.t) ->
                         m.Mailing.start_at
                         |> Mailing.StartAt.value
                         |> Ptime.to_rfc3339 ~space:true)
                       mailing)
                  language
                  `Datetime
                  Pool_common.Message.Field.Start
                  ~flash_fetcher
              ; input_element
                  ?value:
                    (CCOption.map
                       (fun (m : Mailing.t) ->
                         m.Mailing.end_at
                         |> Mailing.EndAt.value
                         |> Ptime.to_rfc3339 ~space:true)
                       mailing)
                  language
                  `Datetime
                  Pool_common.Message.Field.End
                  ~flash_fetcher
              ; input_element
                  ?value:
                    (CCOption.map
                       (fun (m : Mailing.t) ->
                         m.Mailing.rate |> Mailing.Rate.value |> CCInt.to_string)
                       mailing)
                  language
                  `Number
                  Pool_common.Message.Field.Rate
                  ~flash_fetcher
              ]
          ; input_element
              language
              `Text
              Pool_common.Message.Field.Distribution
              ~flash_fetcher
              ?value:
                CCOption.(
                  mailing
                  >>= (fun m -> m.Mailing.distribution)
                  >|= fun m ->
                  m |> Mailing.Distribution.yojson_of_t |> Yojson.Safe.to_string)
            (* TODO: Add detailed description how distribution element works *)
          ; submit_element language submit ()
          ]
      ; div ~a:[ a_class [ "stack" ]; a_id "overlaps" ] []
      ; script (Unsafe.data functions)
      ]
  in
  Page_admin_experiments.experiment_layout
    language
    (Page_admin_experiments.Control submit)
    experiment_id
    html
;;

let create context experiment_id flash_fetcher =
  form context experiment_id flash_fetcher
;;

let edit context experiment_id mailing flash_fetcher =
  form ~mailing context experiment_id flash_fetcher
;;

let overlaps
    ?average_send
    ?total
    (Pool_context.{ language; _ } as context)
    experiment_id
    mailings
  =
  let average =
    match average_send with
    | None -> []
    | Some average ->
      [ p
          [ Format.asprintf
              "%s (ca. %d)"
              Pool_common.(
                I18n.RateNumberPerMinutesHint 5 |> Utils.text_to_string language)
              average
            |> txt
          ]
      ]
  in
  let total =
    match total with
    | None -> []
    | Some total ->
      [ p
          [ Format.asprintf
              "%s %d"
              Pool_common.(I18n.RateTotalSent |> Utils.text_to_string language)
              total
            |> txt
          ]
      ]
  in
  let mailings =
    [ p
        [ Pool_common.(I18n.RateDependencyHint |> Utils.text_to_string language)
          |> txt
        ]
    ]
    @
    match CCList.is_empty mailings with
    | true -> []
    | false -> [ List.create context experiment_id mailings ]
  in
  div (average @ total @ mailings)
;;
