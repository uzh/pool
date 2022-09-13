module Command = Cqrs_command.Contact_command
module HttpUtils = Http_utils

let create_layout = Contact_general.create_layout
let user_update_csrf = "_user_update_csrf"

let show usage req =
  let result ({ Pool_context.tenant_db; language; _ } as context) =
    let open Utils.Lwt_result.Infix in
    let open Lwt_result.Syntax in
    Lwt_result.map_error (fun err -> err, "/login")
    @@ let* user =
         Http_utils.user_from_session tenant_db req
         ||> CCOption.to_result Pool_common.Message.(NotFound Field.User)
       in
       let* contact =
         Contact.find tenant_db (user.Sihl_user.id |> Pool_common.Id.of_string)
         |> Lwt_result.map_error (fun err -> err)
       in
       match usage with
       | `Overview ->
         Page.Contact.detail contact context
         |> create_layout ~active_navigation:"/user" req context
         >|= Sihl.Web.Response.of_html
       | `LoginInformation ->
         let* password_policy =
           I18n.find_by_key tenant_db I18n.Key.PasswordPolicyText language
         in
         Page.Contact.login_information contact context password_policy
         |> create_layout ~active_navigation:"/user" req context
         >|= Sihl.Web.Response.of_html
       | `PersonalDetails ->
         let* tenant_languages =
           Pool_context.Tenant.find req
           |> Lwt_result.lift
           >|= fun c -> c.Pool_context.Tenant.tenant_languages
         in
         Page.Contact.personal_details
           user_update_csrf
           contact
           tenant_languages
           context
         |> create_layout req ~active_navigation:"/user" context
         >|= Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let details = show `Overview
let personal_details = show `PersonalDetails
let login_information = show `LoginInformation

let update req =
  let open Utils.Lwt_result.Infix in
  let open Pool_common.Message in
  let%lwt urlencoded =
    Sihl.Web.Request.to_urlencoded req
    ||> HttpUtils.format_htmx_request_boolean_values Field.[ Paused |> show ]
  in
  let result { Pool_context.csrf; tenant_db; language; query_language; _ } =
    let path_with_lang = HttpUtils.path_with_language query_language in
    let go name = CCList.assoc ~eq:String.equal name urlencoded |> CCList.hd in
    let version_raw = go "version" in
    (* '_name_' with underscores to not match any field constructor function *)
    let _name_ = go "field" |> Field.read in
    let open Utils.Lwt_result.Syntax in
    let* user =
      Http_utils.user_from_session tenant_db req
      ||> CCOption.to_result (NotFound Field.User, path_with_lang "/login")
    in
    let* contact =
      Contact.find tenant_db (user.Sihl_user.id |> Pool_common.Id.of_string)
      |> Lwt_result.map_error (fun err -> err, path_with_lang "/login")
    in
    let* { Pool_context.Tenant.tenant_languages; _ } =
      Pool_context.Tenant.find req
      |> Lwt_result.lift
      |> Lwt_result.map_error (fun err ->
           err, path_with_lang "/user/personal-details")
    in
    let version =
      version_raw
      |> CCInt.of_string
      |> CCOption.get_exn_or
           (Pool_common.Utils.error_to_string
              language
              (NotANumber Field.(_name_ |> show)))
    in
    let get_version =
      CCOption.get_exn_or
        (Pool_common.Utils.error_to_string
           language
           (NotHandled Field.(_name_ |> show)))
    in
    let current_version =
      Contact.version_selector contact Field.(_name_ |> show) |> get_version
    in
    let events =
      let open CCResult.Infix in
      let open Cqrs_command.Contact_command.Update in
      if Pool_common.Version.value current_version <= version
      then urlencoded |> decode >>= handle contact
      else Error (MeantimeUpdate _name_)
    in
    let hx_post = Sihl.Web.externalize_path (path_with_lang "/user/update") in
    let htmx_element contact classnames ?error () =
      let open Contact in
      let csrf_element = Htmx.csrf_element_swap csrf ~id:user_update_csrf () in
      let html_response input =
        let success =
          match error with
          | None -> true
          | Some _ -> false
        in
        [ Htmx.create input language ~classnames ~hx_post ?error ~success ()
        ; csrf_element
        ]
        |> HttpUtils.multi_html_to_plain_text_response
      in
      Lwt_result.return
      @@
      match[@warning "-4"] _name_ with
      | Field.Paused ->
        Htmx.Paused (contact.paused_version, contact.paused) |> html_response
      | Field.Firstname ->
        Htmx.Firstname (contact.firstname_version, contact |> firstname)
        |> html_response
      | Field.Lastname ->
        Htmx.Lastname (contact.lastname_version, contact |> lastname)
        |> html_response
      | Field.Language ->
        (match error with
         | Some _ ->
           Htmx.Language
             (contact.language_version, contact.language, tenant_languages)
           |> html_response
         | None ->
           Sihl.Web.Response.of_plain_text ""
           |> Sihl.Web.Response.add_header
                ("HX-Redirect", "/user/personal-details"))
      | k ->
        failwith
        @@ Pool_common.Utils.error_to_string
             language
             (NotHandled (k |> Field.show))
    in
    match events with
    | Ok events ->
      let%lwt () = Lwt_list.iter_s (Pool_event.handle_event tenant_db) events in
      let* contact =
        Contact.(contact |> id |> find tenant_db)
        |> Lwt_result.map_error (fun err -> err, "/login")
      in
      htmx_element contact [ "success" ] ()
    | Error err -> htmx_element contact [ "error" ] ~error:err ()
  in
  Lwt.catch
    (fun () -> result |> HttpUtils.extract_happy_path req)
    (fun exn ->
      Logs.err (fun m -> m "%s" @@ Printexc.to_string exn);
      Sihl.Web.Response.of_plain_text ""
      |> Sihl.Web.Response.add_header ("HX-Redirect", "/error")
      |> Lwt.return)
;;

let update_email req =
  let open Utils.Lwt_result.Infix in
  let open Pool_common.Message in
  let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
  let result { Pool_context.tenant_db; query_language; _ } =
    let open Lwt_result.Syntax in
    Lwt_result.map_error (fun msg ->
      HttpUtils.(
        msg, "/user/login-information", [ urlencoded_to_flash urlencoded ]))
    @@ let* contact =
         Http_utils.user_from_session tenant_db req
         ||> CCOption.to_result (NotFound Field.User)
         >>= fun user ->
         Contact.find tenant_db (user.Sihl_user.id |> Pool_common.Id.of_string)
       in
       let%lwt allowed_email_suffixes =
         let open Utils.Lwt_result.Infix in
         Settings.find_email_suffixes tenant_db
         ||> fun suffixes ->
         if CCList.is_empty suffixes then None else Some suffixes
       in
       let* new_email =
         Pool_user.EmailAddress.create
           (CCList.assoc ~eq:CCString.equal Field.(Email |> show) urlencoded
           |> CCList.hd)
         |> Lwt_result.lift
       in
       let* events =
         Command.RequestEmailValidation.(
           handle ?allowed_email_suffixes contact new_email |> Lwt_result.lift)
       in
       Utils.Database.with_transaction tenant_db (fun () ->
         let%lwt () = Pool_event.handle_events tenant_db events in
         HttpUtils.(
           redirect_to_with_actions
             (path_with_language query_language "/email-confirmation")
             [ Message.set ~success:[ EmailConfirmationMessage ] ]))
       |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let update_password req =
  let open Utils.Lwt_result.Infix in
  let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
  let result { Pool_context.tenant_db; query_language; _ } =
    let open Lwt_result.Syntax in
    Lwt_result.map_error (fun msg ->
      HttpUtils.(
        msg, "/user/login-information", [ urlencoded_to_flash urlencoded ]))
    @@ let* contact =
         Http_utils.user_from_session tenant_db req
         ||> CCOption.to_result Pool_common.Message.(NotFound Field.User)
         >>= fun user ->
         Contact.find tenant_db (user.Sihl_user.id |> Pool_common.Id.of_string)
       in
       let* events =
         let open CCResult.Infix in
         Command.UpdatePassword.(decode urlencoded >>= handle contact)
         |> Lwt_result.lift
       in
       Utils.Database.with_transaction tenant_db (fun () ->
         let%lwt () = Pool_event.handle_events tenant_db events in
         HttpUtils.(
           redirect_to_with_actions
             (path_with_language query_language "/user/login-information")
             [ Message.set ~success:[ Pool_common.Message.PasswordChanged ] ]))
       |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;
