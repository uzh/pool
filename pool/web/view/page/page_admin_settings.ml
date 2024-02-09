open Tyxml.Html
open Component.Input
module Message = Pool_common.Message
module Queue = Page_admin_settings_queue
module RolePermission = Page_admin_settings_rules
module RoleAssignment = Page_admin_settings_role_assignment
module Schedule = Page_admin_settings_schedule
module Smtp = Page_admin_settings_smtp
module Tags = Page_admin_settings_tags
module TextMessage = Page_admin_settings_text_messages

let show
  tenant_languages
  email_suffixes
  contact_email
  inactive_user_disable_after
  inactive_user_warning
  trigger_profile_update_after
  default_reminder_lead_time
  default_text_msg_reminder_lead_time
  user_import_first_reminder
  user_import_second_reminder
  Pool_context.{ language; csrf; _ }
  text_messages_enabled
  flash_fetcher
  =
  let action_path action =
    Sihl.Web.externalize_path
      (Format.asprintf "/admin/settings/%s" (Settings.stringify_action action))
  in
  let submit ?(control = Message.(Update None)) () =
    div
      ~a:[ a_class [ "flexrow" ] ]
      [ submit_element ~classnames:[ "push" ] language control () ]
  in
  let form_attrs action =
    [ a_method `Post
    ; a_action (action_path action)
    ; a_class [ "stack" ]
    ; a_user_data "detect-unsaved-changes" ""
    ]
  in
  let languages_html =
    let all_languages =
      [ tenant_languages |> CCList.map (fun k -> k, true)
      ; Pool_common.Language.all
        |> CCList.filter_map (fun k ->
          match CCList.mem k tenant_languages with
          | true -> None
          | false -> Some (k, false))
      ]
      |> CCList.flatten
    in
    let field_elements =
      CCList.map
        (fun (language, selected) ->
          let attrs =
            [ a_input_type `Checkbox
            ; a_name (Pool_common.Language.show language)
            ]
          in
          let selected =
            match selected with
            | false -> []
            | true -> [ a_checked () ]
          in
          let checkbox = input ~a:(attrs @ selected) () in
          div [ checkbox; label [ txt (Pool_common.Language.show language) ] ])
        all_languages
      |> Component.Sortable.create_sortable
    in
    div
      [ h2 ~a:[ a_class [ "heading-2" ] ] [ txt "Languages" ]
      ; p
          [ txt
              "You have to add Terms and Condidions before you can activate a \
               new language."
          ]
      ; form
          ~a:(form_attrs `UpdateLanguages)
          ([ csrf_element csrf (); field_elements ] @ [ submit () ])
      ]
  in
  let email_suffixes_html =
    let create_form =
      div
        [ h3
            [ txt
                Pool_common.(
                  Utils.control_to_string
                    language
                    Message.(Add (Some Field.EmailSuffix)))
            ]
        ; form
            ~a:(form_attrs `CreateEmailSuffix)
            [ csrf_element csrf ()
            ; div
                ~a:[ a_class [ "stack" ] ]
                [ input_element
                    language
                    `Text
                    Message.Field.EmailSuffix
                    ~required:true
                ; submit ~control:Message.(Add None) ()
                ]
            ]
        ]
    in
    let delete_forms suffixes =
      suffixes
      |> CCList.map (fun suffix ->
        form
          ~a:
            [ a_method `Post
            ; a_action (action_path `DeleteEmailSuffix)
            ; a_user_data
                "confirmable"
                Pool_common.(
                  Utils.confirmable_to_string language I18n.DeleteEmailSuffix)
            ]
          [ submit_icon ~classnames:[ "error" ] Icon.TrashOutline
          ; input
              ~a:
                [ a_input_type `Hidden
                ; a_name "email_suffix"
                ; a_value (Settings.EmailSuffix.value suffix)
                ; a_readonly ()
                ]
              ()
          ; csrf_element csrf ()
          ])
      |> div ~a:[ a_class [ "flexcolumn"; "stack-xs" ] ]
    in
    let update_forms suffixes =
      form
        ~a:
          [ a_method `Post
          ; a_action (action_path `UpdateEmailSuffixes)
          ; a_user_data "detect-unsaved-changes" ""
          ; a_class [ "grow" ]
          ]
        [ csrf_element csrf ()
        ; div
            ~a:[ a_class [ "flexcolumn"; "stack-xs" ] ]
            (suffixes
             |> CCList.map (fun suffix ->
               input
                 ~a:
                   [ a_value (Settings.EmailSuffix.value suffix)
                   ; a_input_type `Text
                   ; a_name (Message.Field.show Field.EmailSuffix)
                   ; a_required ()
                   ]
                 ()))
        ; div
            ~a:[ a_class [ "flexrow"; "gap" ] ]
            [ submit_element
                ~classnames:[ "push" ]
                language
                Message.(Update None)
                ()
            ]
        ]
    in
    let suffix_rows suffixes =
      div
        ~a:[ a_class [ "flexrow"; "flex-gap" ] ]
        [ update_forms suffixes; delete_forms suffixes ]
    in
    div
      [ h2 ~a:[ a_class [ "heading-2" ] ] [ txt "Email Suffixes" ]
      ; div
          ~a:[ a_class [ "stack"; "flexcolumn" ] ]
          [ (match email_suffixes with
             | [] ->
               div
                 [ txt
                     Pool_common.(
                       Utils.hint_to_string
                         language
                         I18n.SettingsNoEmailSuffixes)
                 ]
             | suffixes -> suffix_rows suffixes)
          ; create_form
          ]
      ]
  in
  let contact_email_html =
    div
      [ h2 [ txt "Contact Email" ]
      ; form
          ~a:(form_attrs `UpdateContactEmail)
          [ csrf_element csrf ()
          ; input_element
              language
              `Text
              Message.Field.ContactEmail
              ~value:(contact_email |> Settings.ContactEmail.value)
              ~required:true
          ; submit ~control:Message.(Add None) ()
          ]
      ]
  in
  let inactive_user_html =
    let open Settings.InactiveUser in
    div
      [ h2 ~a:[ a_class [ "heading-2" ] ] [ txt "Inactive Users" ]
      ; div
          ~a:[ a_class [ "stack" ] ]
          [ form
              ~a:(form_attrs `UpdateInactiveUserDisableAfter)
              [ csrf_element csrf ()
              ; timespan_picker
                  ~required:true
                  language
                  Message.Field.InactiveUserDisableAfter
                  ~value:(inactive_user_disable_after |> DisableAfter.value)
              ; submit ()
              ]
          ; form
              ~a:(form_attrs `UpdateInactiveUserWarning)
              [ csrf_element csrf ()
              ; timespan_picker
                  ~required:true
                  language
                  Message.Field.InactiveUserWarning
                  ~value:(inactive_user_warning |> Warning.value)
              ; submit ()
              ]
          ]
      ]
  in
  let trigger_profile_update_after_html =
    let open Settings.TriggerProfileUpdateAfter in
    div
      [ h2
          ~a:[ a_class [ "heading-2" ] ]
          [ Pool_common.(
              Utils.field_to_string
                language
                Message.Field.TriggerProfileUpdateAfter)
            |> CCString.capitalize_ascii
            |> txt
          ]
      ; div
          ~a:[ a_class [ "stack" ] ]
          [ form
              ~a:(form_attrs `UpdateTriggerProfileUpdateAfter)
              [ csrf_element csrf ()
              ; timespan_picker
                  ~required:true
                  language
                  Message.Field.TriggerProfileUpdateAfter
                  ~value:(trigger_profile_update_after |> value)
              ; submit ()
              ]
          ]
      ]
  in
  let default_lead_time =
    let lead_time_form action field value encode =
      form
        ~a:(form_attrs action)
        [ csrf_element csrf ()
        ; timespan_picker
            ~value:(value |> encode)
            ~required:true
            ~flash_fetcher
            language
            field
        ; submit ()
        ]
    in
    let text_message_lead_time =
      let input_el =
        lead_time_form
          `UpdateTextMsgDefaultLeadTime
          Message.Field.TextMessageLeadTime
          default_text_msg_reminder_lead_time
          Pool_common.Reminder.TextMessageLeadTime.value
      in
      match text_messages_enabled with
      | true -> input_el
      | false ->
        div
          ~a:[ a_class [ "stack" ] ]
          [ Pool_common.(
              I18n.GtxKeyMissing
              |> Utils.hint_to_string language
              |> txt
              |> CCList.return
              |> Component.Notification.notification language `Warning)
          ; input_el
          ]
    in
    div
      [ h2 [ txt "Reminder lead time" ]
      ; p
          [ txt
              Pool_common.(
                Utils.hint_to_string language I18n.SessionReminderLeadTime)
          ]
      ; div
          ~a:[ a_class [ "stack" ] ]
          [ lead_time_form
              `UpdateDefaultLeadTime
              Message.Field.EmailLeadTime
              default_reminder_lead_time
              Pool_common.Reminder.EmailLeadTime.value
          ; text_message_lead_time
          ]
      ]
  in
  let user_import_reminder =
    let open Settings.UserImportReminder in
    let enabled_time_units = [ Pool_common.Model.TimeUnit.Days ] in
    let timespan_picker field value =
      timespan_picker
        ~enabled_time_units
        ~min_value:(`Number 1)
        ~required:true
        language
        field
        ~value
    in
    div
      [ h2 ~a:[ a_class [ "heading-2" ] ] [ txt "User import" ]
      ; div
          [ Pool_common.(Utils.hint_to_string language I18n.UserImportInterval)
            |> Unsafe.data
          ]
      ; div
          ~a:[ a_class [ "stack"; "gap" ] ]
          [ form
              ~a:(form_attrs `UserImportFirstReminderAfter)
              [ csrf_element csrf ()
              ; timespan_picker
                  Message.Field.FirstReminder
                  (user_import_first_reminder |> FirstReminderAfter.value)
              ; submit ()
              ]
          ; form
              ~a:(form_attrs `UserImportSecondReminderAfter)
              [ csrf_element csrf ()
              ; timespan_picker
                  Message.Field.SecondReminder
                  (user_import_second_reminder |> SecondReminderAfter.value)
              ; submit ()
              ]
          ]
      ]
  in
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1 ~a:[ a_class [ "heading-1" ] ] [ txt "Settings" ]
    ; div
        ~a:[ a_class [ "stack" ] ]
        [ languages_html
        ; email_suffixes_html
        ; contact_email_html
        ; inactive_user_html
        ; trigger_profile_update_after_html
        ; default_lead_time
        ; user_import_reminder
        ]
    ]
;;
