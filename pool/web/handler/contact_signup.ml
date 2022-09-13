module Command = Cqrs_command.Contact_command
module HttpUtils = Http_utils

let create_layout = Contact_general.create_layout

let sign_up req =
  let result ({ Pool_context.tenant_db; language; _ } as context) =
    let open Lwt_result.Syntax in
    let open Lwt_result.Infix in
    Lwt_result.map_error (fun err -> err, "/index")
    @@
    let flash_fetcher key = Sihl.Web.Flash.find key req in
    let* terms = Settings.terms_and_conditions tenant_db language in
    Page.Contact.sign_up terms context flash_fetcher
    |> create_layout req ~active_navigation:"/signup" context
    >|= Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let sign_up_create req =
  let open Utils.Lwt_result.Infix in
  let open Pool_common.Message in
  let terms_key = Field.(TermsAccepted |> show) in
  let%lwt urlencoded =
    Sihl.Web.Request.to_urlencoded req
    ||> HttpUtils.format_request_boolean_values [ terms_key ]
  in
  let result { Pool_context.tenant_db; query_language; _ } =
    let open Lwt_result.Syntax in
    Lwt_result.map_error (fun msg ->
      msg, "/signup", [ HttpUtils.urlencoded_to_flash urlencoded ])
    @@ let* () =
         CCList.assoc ~eq:( = ) terms_key urlencoded
         |> CCList.hd
         |> CCString.equal "true"
         |> Utils.Bool.to_result TermsAndConditionsNotAccepted
         |> Lwt_result.lift
       in
       let* remove_contact_event =
         let find_contact email =
           email
           |> Contact.find_by_email tenant_db
           ||> function
           | Ok partitipant ->
             if partitipant.Contact.user.Sihl_user.confirmed
             then Error EmailAlreadyInUse
             else Ok (Some partitipant)
           | Error _ -> Ok None
         in
         Sihl.Web.Request.urlencoded Field.(Email |> show) req
         ||> CCOption.to_result ContactSignupInvalidEmail
         >== Pool_user.EmailAddress.create
         >>= find_contact
         >>= CCOption.map_or ~default:(Lwt_result.return []) (fun p ->
               Command.DeleteUnverified.handle p |> Lwt_result.lift)
       in
       let%lwt allowed_email_suffixes =
         let open Utils.Lwt_result.Infix in
         Settings.find_email_suffixes tenant_db
         ||> fun suffixes ->
         if CCList.is_empty suffixes then None else Some suffixes
       in
       let preferred_language = HttpUtils.browser_language_from_req req in
       let* events =
         let open CCResult.Infix in
         Command.SignUp.(
           decode urlencoded
           >>= handle ?allowed_email_suffixes preferred_language)
         >>= (fun e -> Ok (remove_contact_event @ e))
         |> Lwt_result.lift
       in
       Utils.Database.with_transaction tenant_db (fun () ->
         let%lwt () = Pool_event.handle_events tenant_db events in
         HttpUtils.(
           redirect_to_with_actions
             (path_with_language query_language "/email-confirmation")
             [ Message.set
                 ~success:[ Pool_common.Message.EmailConfirmationMessage ]
             ]))
       |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let email_verification req =
  let open Utils.Lwt_result.Infix in
  let result { Pool_context.tenant_db; query_language; _ } =
    let open Lwt_result.Syntax in
    let open Pool_common.Message in
    let%lwt redirect_path =
      let%lwt user = Http_utils.user_from_session tenant_db req in
      CCOption.bind user (fun user ->
        Some (General.dashboard_path tenant_db user))
      |> CCOption.value ~default:("/login" |> Lwt.return)
    in
    (let* token =
       Sihl.Web.Request.query Field.(show Token) req
       |> CCOption.map Email.Token.create
       |> CCOption.to_result Field.(NotFound Token)
       |> Lwt_result.lift
     in
     let ctx = Pool_tenant.to_ctx tenant_db in
     let* email =
       Service.Token.read
         ~ctx
         (Email.Token.value token)
         ~k:Field.(Email |> show)
       ||> CCOption.to_result TokenInvalidFormat
       >== Pool_user.EmailAddress.create
       >>= Email.find_unverified_by_address tenant_db
       |> Lwt_result.map_error (fun _ -> Field.(Invalid Token))
     in
     let* contact = Contact.find tenant_db (Email.user_id email) in
     let* events =
       match contact.Contact.user.Sihl.Contract.User.confirmed with
       | false ->
         Command.VerifyEmail.(handle contact { email }) |> Lwt_result.lift
       | true -> Command.UpdateEmail.(handle contact email) |> Lwt_result.lift
     in
     let%lwt () = Pool_event.handle_events tenant_db events in
     HttpUtils.(
       redirect_to_with_actions
         (path_with_language query_language redirect_path)
         [ Message.set ~success:[ EmailVerified ] ])
     |> Lwt_result.ok)
    |> Lwt_result.map_error (fun msg -> msg, redirect_path)
  in
  result |> HttpUtils.extract_happy_path req
;;

let terms req =
  let open Utils.Lwt_result.Infix in
  let open Lwt_result.Syntax in
  let result ({ Pool_context.tenant_db; language; _ } as context) =
    Lwt_result.map_error (fun err -> err, "/login")
    @@ let* user =
         Http_utils.user_from_session tenant_db req
         ||> CCOption.to_result Pool_common.Message.(NotFound Field.User)
       in
       let* terms = Settings.terms_and_conditions tenant_db language in
       Page.Contact.terms user.Sihl_user.id terms context
       |> create_layout req context
       >|= Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let terms_accept req =
  let result { Pool_context.tenant_db; query_language; _ } =
    Lwt_result.map_error (fun msg -> msg, "/login")
    @@
    let open Lwt_result.Syntax in
    let id =
      Pool_common.(
        Sihl.Web.Router.param req Message.Field.(Id |> show) |> Id.of_string)
    in
    let* contact = Contact.find tenant_db id in
    let* events =
      Command.AcceptTermsAndConditions.handle contact |> Lwt_result.lift
    in
    let%lwt () = Pool_event.handle_events tenant_db events in
    HttpUtils.(redirect_to (path_with_language query_language "/dashboard"))
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path req
;;
