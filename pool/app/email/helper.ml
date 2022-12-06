open Entity
module User = Pool_user
module Database = Pool_database

let string_to_html =
  let open CCFun in
  CCString.split ~by:"\n\n"
  %> CCList.map (Utils.Html.handle_line_breaks Tyxml.Html.p)
;;

let create_public_url pool_url path =
  path
  |> Sihl.Web.externalize_path
  |> Format.asprintf "http://%s%s" (Pool_tenant.Url.value pool_url)
;;

let prepend_root_directory pool url =
  match Database.Label.equal pool Database.root with
  | true -> Format.asprintf "/root%s" url
  | false -> url
;;

(* TODO [aerben] make this result isntead of exception *)
let prepare_email pool language label subject email params =
  let%lwt template =
    Service.EmailTemplate.get_by_label
      ~ctx:(Pool_tenant.to_ctx pool)
      ~language:(Pool_common.Language.show language)
      (TemplateLabel.show label)
  in
  match template, Sihl.Configuration.read_string "SMTP_SENDER" with
  | _, None -> failwith "SMTP_SENDER not found in configuration"
  (* TODO [aerben] no exceptions here *)
  | None, _ -> failwith "Email template not found!"
  | Some template, Some sender ->
    let mail =
      Sihl_email.
        { sender
        ; recipient = email
        ; subject
        ; text = ""
        ; html = None
        ; cc = []
        ; bcc = []
        }
    in
    Sihl_email.Template.email_of_template ~template mail params
;;

let prepare_boilerplate_email template email params =
  match Sihl.Configuration.read_string "SMTP_SENDER" with
  | None -> failwith "SMTP_SENDER not found in configuration"
  | Some sender ->
    let CustomTemplate.{ subject; content } = template in
    let subject = subject |> CustomTemplate.Subject.value in
    let text = content |> CustomTemplate.Content.value in
    let html =
      Default_utils.(
        combine_html
          Pool_common.Language.En
          (Some subject)
          (text |> string_to_html)
        |> html_to_string)
    in
    let mail =
      Sihl_email.
        { sender
        ; recipient = email
        ; subject
        ; text
        ; html = Some html
        ; cc = []
        ; bcc = []
        }
    in
    Sihl_email.Template.email_of_template mail params
;;

module PasswordReset = struct
  let create pool language ({ Sihl_user.email; _ } as user) =
    let%lwt url = Pool_tenant.Url.of_pool pool in
    let%lwt reset_token =
      Service.PasswordReset.create_reset_token
        ~ctx:(Pool_tenant.to_ctx pool)
        email
    in
    match reset_token with
    | None ->
      Logs.err (fun m -> m "Reset token not found");
      Lwt.return_error Pool_common.Message.PasswordResetFailMessage
    | Some token ->
      let subject = "Password reset" in
      let reset_url =
        Pool_common.
          [ Message.Field.Token, token
          ; ( Message.Field.Language
            , language |> Pool_common.Language.show |> CCString.lowercase_ascii
            )
          ]
        |> Pool_common.Message.add_field_query_params "/reset-password/"
        |> prepend_root_directory pool
        |> create_public_url url
      in
      Logs.info (fun m -> m "%s" reset_url);
      prepare_email
        pool
        language
        TemplateLabel.PasswordReset
        subject
        email
        [ "resetUrl", reset_url; "name", user |> User.user_fullname ]
      |> Lwt_result.ok
  ;;
end

module PasswordChange = struct
  let create pool language email firstname lastname =
    let name =
      Format.asprintf
        "%s %s"
        (User.Firstname.value firstname)
        (User.Lastname.value lastname)
    in
    let subject = "Password has been changed" in
    prepare_email
      pool
      language
      TemplateLabel.PasswordChange
      subject
      (email |> Pool_user.EmailAddress.value)
      [ "name", name ]
  ;;
end

module ConfirmationEmail = struct
  let create pool language email firstname lastname label =
    let%lwt url = Pool_tenant.Url.of_pool pool in
    let name =
      CCString.concat
        " "
        (CCList.filter_map
           CCFun.id
           [ firstname |> CCOption.map Pool_user.Firstname.value
           ; lastname |> CCOption.map Pool_user.Lastname.value
           ])
    in
    let subject = "Email verification" in
    let validation_url =
      Pool_common.[ Message.Field.Token, token email ]
      |> Pool_common.Message.add_field_query_params "/email-verified"
      |> create_public_url url
    in
    prepare_email
      pool
      language
      label
      subject
      (address email |> Pool_user.EmailAddress.value)
      [ "verificationUrl", validation_url; "name", name ]
  ;;
end
