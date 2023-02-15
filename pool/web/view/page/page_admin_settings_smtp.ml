open Tyxml.Html
open Component.Input
module Message = Pool_common.Message
module Field = Message.Field
module SmtpAuth = Pool_tenant.SmtpAuth

let show
  ?(settings_path = "/admin/settings")
  Pool_context.{ language; csrf; _ }
  flash_fetcher
  { SmtpAuth.id; label; server; port; username; mechanism; protocol }
  =
  let action_path sub =
    Sihl.Web.externalize_path
      (Format.asprintf "%s/smtp/%s%s" settings_path (SmtpAuth.Id.value id) sub)
  in
  let submit
    ?submit_type
    ?(has_icon = `Save)
    ?(control = Message.(Update None))
    ()
    =
    div
      ~a:[ a_class [ "flexrow" ] ]
      [ submit_element
          ?submit_type
          ~has_icon
          ~classnames:[ "push" ]
          language
          control
          ()
      ]
  in
  let form_attrs action_path =
    [ a_method `Post
    ; a_action action_path
    ; a_class [ "stack" ]
    ; a_user_data "detect-unsaved-changes" ""
    ]
  in
  let input_element_root
    ?(required = true)
    ?(field_type = `Text)
    field
    decode_fcn
    value
    =
    input_element
      ~required
      ~value:(value |> decode_fcn)
      ~flash_fetcher
      language
      field_type
      field
  in
  let smtp_details =
    let open SmtpAuth in
    div
      [ form
          ~a:(action_path "" |> form_attrs)
          [ csrf_element csrf ()
          ; input_element
              ~value:(Label.value label)
              language
              `Hidden
              Field.SmtpLabel
          ; input_element_root Field.SmtpServer Server.value server
          ; input_element_root
              ~field_type:`Number
              Field.SmtpPort
              CCFun.(Port.value %> CCInt.to_string)
              port
          ; input_element
              ?value:(CCOption.map Username.value username)
              language
              `Text
              Field.SmtpUsername
          ; input_element_root Field.SmtpMechanism Mechanism.value mechanism
          ; input_element_root Field.SmtpProtocol Protocol.value protocol
          ; submit ()
          ]
      ]
  in
  let smtp_password =
    div
      ~a:[ a_class [ "stack" ] ]
      [ h2 ~a:[ a_class [ "heading-2" ] ] [ txt "Update or Delete Password" ]
      ; form
          ~a:(action_path "/password" |> form_attrs)
          [ csrf_element csrf ()
          ; input_element
              ~value:""
              ~required:true
              language
              `Password
              Field.SmtpPassword
          ; submit ()
          ]
      ; form
          ~a:(action_path "/password" |> form_attrs)
          [ csrf_element csrf ()
          ; input_element ~value:"" language `Hidden Field.SmtpPassword
          ; submit
              ~submit_type:`Error
              ~has_icon:`Trash
              ~control:(Message.Delete (Some Field.Password))
              ()
          ]
      ]
  in
  div
    ~a:[ a_class [ "trim"; "narrow"; "safety-margin" ] ]
    [ h1 ~a:[ a_class [ "heading-1" ] ] [ txt "Email Server Settings (SMTP)" ]
    ; div ~a:[ a_class [ "stack" ] ] [ smtp_details; smtp_password ]
    ]
;;
