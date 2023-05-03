module HttpUtils = Http_utils
module Message = HttpUtils.Message
module Field = Pool_common.Message.Field

let create_layout req = General.create_tenant_layout req
let experiment_id = HttpUtils.find_id Experiment.Id.of_string Field.Experiment
let session_id = HttpUtils.find_id Session.Id.of_string Field.Session

let template_id =
  HttpUtils.find_id
    Message_template.Id.of_string
    Pool_common.Message.Field.MessageTemplate
;;

let location urlencoded database_label =
  let open Utils.Lwt_result.Infix in
  let open Pool_common.Message in
  Field.(Location |> show)
  |> CCList.pure
  |> HttpUtils.urlencoded_to_params urlencoded
  |> CCOption.to_result (NotFound Field.Location)
  |> Lwt_result.lift
  >|+ List.assoc Field.(Location |> show)
  >|+ Pool_location.Id.of_string
  >>= Pool_location.find database_label
;;

let list req =
  let open Utils.Lwt_result.Infix in
  let error_path = "/admin/dashboard" in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@
    let experiment_id = experiment_id req in
    let* experiment = Experiment.find database_label experiment_id in
    let* sessions =
      Session.find_all_for_experiment database_label experiment_id
    in
    let grouped_sessions, chronological =
      match
        Sihl.Web.Request.query
          Pool_common.Message.Field.(show Chronological)
          req
      with
      | Some "true" -> CCList.map (fun s -> s, []) sessions, true
      | None | Some _ -> Session.group_and_sort sessions, false
    in
    Page.Admin.Session.index context experiment grouped_sessions chronological
    >|> create_layout req context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let new_helper req page =
  let open Utils.Lwt_result.Infix in
  let open Session in
  let id = experiment_id req in
  let error_path =
    Format.asprintf "/admin/experiments/%s/sessions" (id |> Experiment.Id.value)
  in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@ let* experiment = Experiment.find database_label id in
       let%lwt duplicate_session =
         match Sihl.Web.Request.query "duplicate_id" req with
         | Some id ->
           id |> Id.of_string |> find database_label ||> CCResult.to_opt
         | None -> Lwt.return None
       in
       let%lwt locations = Pool_location.find_all database_label in
       let flash_fetcher = CCFun.flip Sihl.Web.Flash.find req in
       let%lwt default_reminder_lead_time =
         Settings.find_default_reminder_lead_time database_label
       in
       let html =
         match page with
         | `FollowUp ->
           let session_id = session_id req in
           let* parent_session = find database_label session_id in
           Page.Admin.Session.follow_up
             context
             experiment
             default_reminder_lead_time
             duplicate_session
             parent_session
             locations
             flash_fetcher
           |> Lwt_result.ok
         | `Parent ->
           Page.Admin.Session.new_form
             context
             experiment
             default_reminder_lead_time
             duplicate_session
             locations
             flash_fetcher
           |> Lwt_result.ok
       in
       html >>= create_layout req context >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let new_form req = new_helper req `Parent
let follow_up req = new_helper req `FollowUp

let create req =
  let id = experiment_id req in
  let path =
    Format.asprintf "/admin/experiments/%s/sessions" (Experiment.Id.value id)
  in
  let result context =
    let open Utils.Lwt_result.Infix in
    let tags = Pool_context.Logger.Tags.req req in
    let%lwt urlencoded =
      Sihl.Web.Request.to_urlencoded req ||> HttpUtils.remove_empty_values
    in
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , Format.asprintf "%s/%s" path "create"
      , [ HttpUtils.urlencoded_to_flash urlencoded ] ))
    @@
    let database_label = context.Pool_context.database_label in
    let* location = location urlencoded database_label in
    let* events =
      let open CCResult.Infix in
      let open Cqrs_command.Session_command.Create in
      urlencoded |> decode >>= handle ~tags id location |> Lwt_result.lift
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.redirect_to_with_actions
      path
      [ Message.set ~success:[ Pool_common.Message.(Created Field.Session) ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let detail req page =
  let open Utils.Lwt_result.Infix in
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let error_path =
    Format.asprintf
      "/admin/experiments/%s/sessions"
      (Experiment.Id.value experiment_id)
  in
  let result context =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@
    let database_label = context.Pool_context.database_label in
    let* session = Session.find database_label session_id in
    let* experiment = Experiment.find database_label experiment_id in
    let flash_fetcher = CCFun.flip Sihl.Web.Flash.find req in
    (match page with
     | `Detail ->
       let* assignments =
         Assignment.find_by_session database_label session.Session.id
       in
       Page.Admin.Session.detail context experiment session assignments
       |> Lwt_result.ok
     | `Edit ->
       let%lwt locations = Pool_location.find_all database_label in
       let%lwt session_reminder_templates =
         Message_template.find_all_of_entity_by_label
           database_label
           (session_id |> Session.Id.to_common)
           Message_template.Label.SessionReminder
       in
       let%lwt default_reminder_lead_time =
         Settings.find_default_reminder_lead_time database_label
       in
       let* sys_languages =
         Pool_context.Tenant.get_tenant_languages req |> Lwt_result.lift
       in
       Page.Admin.Session.edit
         context
         experiment
         default_reminder_lead_time
         session
         locations
         session_reminder_templates
         sys_languages
         flash_fetcher
       |> Lwt_result.ok
     | `Close ->
       let* assignments =
         Assignment.find_uncanceled_by_session database_label session.Session.id
       in
       Page.Admin.Session.close context experiment session assignments
       |> Lwt_result.ok
     | `Reschedule ->
       let* experiment = Experiment.find database_label experiment_id in
       Page.Admin.Session.reschedule_session
         context
         experiment
         session
         flash_fetcher
       |> Lwt_result.ok
     | `Cancel ->
       let* follow_ups = Session.find_follow_ups database_label session_id in
       Page.Admin.Session.cancel
         context
         experiment
         session
         follow_ups
         flash_fetcher
       |> Lwt_result.ok)
    >>= create_layout req context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let show req = detail req `Detail
let edit req = detail req `Edit
let reschedule_form req = detail req `Reschedule
let cancel_form req = detail req `Cancel
let close req = detail req `Close

let update_handler action req =
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let path =
    Format.asprintf
      "/admin/experiments/%s/sessions/%s"
      (Experiment.Id.value experiment_id)
      (Session.Id.value session_id)
  in
  let error_path, success_msg =
    let open Pool_common.Message in
    match action with
    | `Update -> "edit", Updated Field.session
    | `Reschedule -> "reschedule", Rescheduled Field.session
  in
  let result { Pool_context.database_label; _ } =
    let open Utils.Lwt_result.Infix in
    let%lwt urlencoded =
      Sihl.Web.Request.to_urlencoded req ||> HttpUtils.remove_empty_values
    in
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , Format.asprintf "%s/%s" path error_path
      , [ HttpUtils.urlencoded_to_flash urlencoded ] ))
    @@
    let tags = Pool_context.Logger.Tags.req req in
    let* { Pool_context.Tenant.tenant; _ } =
      Pool_context.Tenant.find req |> Lwt_result.lift
    in
    let* session = Session.find database_label session_id in
    let* follow_ups =
      Session.find_follow_ups database_label session.Session.id
    in
    let* parent =
      match session.Session.follow_up_to with
      | None -> Lwt_result.return None
      | Some parent_id ->
        parent_id |> Session.find database_label >|+ CCOption.some
    in
    let* events =
      match action with
      | `Update ->
        let* location = location urlencoded database_label in
        let open CCResult.Infix in
        let open Cqrs_command.Session_command.Update in
        urlencoded
        |> decode
        >>= handle ~tags ?parent_session:parent follow_ups session location
        |> Lwt_result.lift
      | `Reschedule ->
        let open Cqrs_command.Session_command.Reschedule in
        let* assignments =
          Assignment.find_by_session database_label session.Session.id
        in
        let* system_languages =
          Pool_context.Tenant.get_tenant_languages req |> Lwt_result.lift
        in
        let* create_message =
          Message_template.SessionReschedule.prepare
            database_label
            tenant
            system_languages
            session
        in
        urlencoded
        |> decode
        |> Lwt_result.lift
        >== handle
              ~tags
              ?parent_session:parent
              follow_ups
              session
              assignments
              create_message
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.redirect_to_with_actions
      path
      [ Message.set ~success:[ success_msg ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let update = update_handler `Update
let reschedule = update_handler `Reschedule

let cancel req =
  let open Utils.Lwt_result.Infix in
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let success_path =
    Format.asprintf
      "/admin/experiments/%s/sessions/%s"
      (Experiment.Id.value experiment_id)
      (Session.Id.value session_id)
  in
  let error_path = CCFormat.asprintf "%s/cancel" success_path in
  let%lwt urlencoded =
    Sihl.Web.Request.to_urlencoded req
    ||> HttpUtils.remove_empty_values
    ||> HttpUtils.format_request_boolean_values
          Pool_common.Message.Field.[ show Email; show SMS ]
  in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err ->
      err, error_path, [ HttpUtils.urlencoded_to_flash urlencoded ])
    @@
    let tags = Pool_context.Logger.Tags.req req in
    let* experiment = Experiment.find database_label experiment_id in
    let* session = Session.find database_label session_id in
    let* follow_ups =
      Session.find_follow_ups database_label session.Session.id
    in
    let* assignments =
      session :: follow_ups
      |> Lwt_list.fold_left_s
           (fun result session ->
             match result with
             | Error err -> Lwt_result.fail err
             | Ok assignments ->
               Assignment.find_uncanceled_by_session
                 database_label
                 session.Session.id
               >|+ CCList.append assignments)
           (Ok [])
      >|+ Assignment.group_by_contact
    in
    let* events =
      let* system_languages =
        Pool_context.Tenant.get_tenant_languages req |> Lwt_result.lift
      in
      let* { Pool_context.Tenant.tenant; _ } =
        Pool_context.Tenant.find req |> Lwt_result.lift
      in
      let* create_message =
        Message_template.SessionCancellation.prepare
          database_label
          tenant
          experiment
          system_languages
          session
          follow_ups
      in
      let open CCResult.Infix in
      let open Cqrs_command.Session_command.Cancel in
      urlencoded
      |> decode
      >>= handle ~tags (session :: follow_ups) assignments create_message
      |> Lwt_result.lift
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.redirect_to_with_actions
      success_path
      [ Message.set ~success:[ Pool_common.Message.(Canceled Field.Session) ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let delete req =
  let experiment_id = experiment_id req in
  let error_path =
    Format.asprintf
      "/admin/experiments/%s/sessions"
      (Experiment.Id.value experiment_id)
  in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err -> err, error_path)
    @@
    let open Utils.Lwt_result.Infix in
    let tags = Pool_context.Logger.Tags.req req in
    let session_id = session_id req in
    let* session = Session.find database_label session_id in
    let* follow_ups = Session.find_follow_ups database_label session_id in
    let%lwt templates =
      let open Message_template in
      find_all_of_entity_by_label
        database_label
        (session_id |> Session.Id.to_common)
        Label.SessionReminder
    in
    let* events =
      let open Cqrs_command.Session_command.Delete in
      { session; follow_ups; templates } |> handle ~tags |> Lwt_result.lift
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.redirect_to_with_actions
      error_path
      [ Message.set ~success:[ Pool_common.Message.(Deleted Field.Session) ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path req
;;

(* TODO [aerben] make possible to create multiple follow ups? *)
let create_follow_up req =
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let path =
    Format.asprintf
      "/admin/experiments/%s/sessions/%s"
      (Experiment.Id.value experiment_id)
      (Session.Id.value session_id)
  in
  let result { Pool_context.database_label; _ } =
    let open Utils.Lwt_result.Infix in
    let%lwt urlencoded =
      Sihl.Web.Request.to_urlencoded req ||> HttpUtils.remove_empty_values
    in
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , Format.asprintf "%s/follow-up" path
      , [ HttpUtils.urlencoded_to_flash urlencoded ] ))
    @@
    let tags = Pool_context.Logger.Tags.req req in
    let* location = location urlencoded database_label in
    let* session = Session.find database_label session_id in
    let* events =
      let open CCResult.Infix in
      let open Cqrs_command.Session_command.Create in
      urlencoded
      |> decode
      >>= handle ~tags ~parent_session:session experiment_id location
      |> Lwt_result.lift
    in
    let%lwt () = Pool_event.handle_events ~tags database_label events in
    Http_utils.redirect_to_with_actions
      (Format.asprintf
         "/admin/experiments/%s/sessions"
         (Experiment.Id.value experiment_id))
      [ Message.set ~success:[ Pool_common.Message.(Created Field.Session) ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path_with_actions req
;;

let close_post req =
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let path =
    Format.asprintf
      "/admin/experiments/%s/sessions/%s"
      (Experiment.Id.value experiment_id)
      (Session.Id.value session_id)
  in
  let result { Pool_context.database_label; _ } =
    let open Utils.Lwt_result.Infix in
    Lwt_result.map_error (fun err -> err, Format.asprintf "%s/close" path)
    @@
    let open Cqrs_command.Assignment_command in
    let open Assignment in
    let* session = Session.find database_label session_id in
    let* assignments =
      Assignment.find_uncanceled_by_session database_label session.Session.id
    in
    let* events =
      let urlencoded_list field =
        Sihl.Web.Request.urlencoded_list
          Pool_common.Message.Field.(array_key field)
          req
      in
      let%lwt no_shows = urlencoded_list Pool_common.Message.Field.NoShow in
      let%lwt participated =
        urlencoded_list Pool_common.Message.Field.Participated
      in
      assignments
      |> Lwt_list.map_s (fun ({ Assignment.id; _ } as assigment) ->
           let id = Id.value id in
           let find = CCList.mem ~eq:CCString.equal id in
           let no_show = no_shows |> find |> NoShow.create in
           let participated = participated |> find |> Participated.create in
           let%lwt follow_ups =
             match
               NoShow.value no_show || not (Participated.value participated)
             with
             | true ->
               find_follow_ups database_label assigment ||> CCOption.return
             | false -> Lwt.return_none
           in
           Lwt.return (assigment, no_show, participated, follow_ups))
      ||> SetAttendance.handle session
    in
    let%lwt () = Pool_event.handle_events database_label events in
    Http_utils.redirect_to_with_actions
      path
      [ Message.set ~success:[ Pool_common.Message.(Closed Field.Session) ] ]
    |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path req
;;

let message_template_form ?template_id label req =
  let open Utils.Lwt_result.Infix in
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err ->
      ( err
      , experiment_id
        |> Experiment.Id.value
        |> Format.asprintf "/admin/experiments/%s/edit" ))
    @@
    let flash_fetcher key = Sihl.Web.Flash.find key req in
    let* { Pool_context.Tenant.tenant; _ } =
      Pool_context.Tenant.find req |> Lwt_result.lift
    in
    let* experiment = Experiment.find database_label experiment_id in
    let* session = Session.find database_label session_id in
    let* template =
      template_id
      |> CCOption.map_or ~default:(Lwt_result.return None) (fun id ->
           Message_template.find database_label id >|+ CCOption.pure)
    in
    let* available_languages =
      match template_id with
      | None ->
        Pool_context.Tenant.get_tenant_languages req
        |> Lwt_result.lift
        |>> Message_template.find_available_languages
              database_label
              (session_id |> Session.Id.to_common)
              label
        >|+ CCOption.pure
      | Some _ -> Lwt_result.return None
    in
    Page.Admin.Session.message_template_form
      context
      tenant
      experiment
      session
      available_languages
      label
      template
      flash_fetcher
    >|> create_layout req context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path req
;;

let new_session_reminder req =
  message_template_form Message_template.Label.SessionReminder req
;;

let new_session_reminder_post req =
  let open Admin_message_templates in
  let experiment_id = experiment_id req in
  let session_id = session_id req |> Session.Id.to_common in
  let label = Message_template.Label.SessionReminder in
  let redirect =
    let base =
      Format.asprintf
        "/admin/experiments/%s/sessions/%s/%s"
        (Experiment.Id.value experiment_id)
        (Pool_common.Id.value session_id)
    in
    { success = base "edit"
    ; error = base (Message_template.Label.prefixed_human_url label)
    }
  in
  (write (Create (session_id, label, redirect))) req
;;

let edit_template req =
  let template_id = template_id req in
  message_template_form
    ~template_id
    Message_template.Label.ExperimentInvitation
    req
;;

let update_template req =
  let open Admin_message_templates in
  let open Utils.Lwt_result.Infix in
  let open Message_template in
  let experiment_id = experiment_id req in
  let session_id = session_id req in
  let template_id = template_id req in
  let session_path =
    Format.asprintf
      "/admin/experiments/%s/sessions/%s/%s"
      (Experiment.Id.value experiment_id)
      (Session.Id.value session_id)
  in
  let%lwt template =
    req
    |> database_label_of_req
    |> Lwt_result.lift
    >>= CCFun.flip find template_id
  in
  match template with
  | Ok template ->
    let redirect =
      { success = session_path "edit"
      ; error = session_path (prefixed_template_url ~append:"edit" template)
      }
    in
    (write (Update (template_id, redirect))) req
  | Error err ->
    HttpUtils.redirect_to_with_actions
      (session_path "edit")
      [ HttpUtils.Message.set ~error:[ err ] ]
;;

module Access : sig
  include module type of Helpers.Access

  val reschedule : Rock.Middleware.t
  val cancel : Rock.Middleware.t
  val send_reminder : Rock.Middleware.t
  val close : Rock.Middleware.t
end = struct
  module SessionCommand = Cqrs_command.Session_command
  module Guardian = Middleware.Guardian

  let experiment_effects =
    Guardian.id_effects Experiment.Id.of_string Field.Experiment
  ;;

  let combined_effects fcn req =
    let open HttpUtils in
    let experiment_id = find_id Experiment.Id.of_string Field.Experiment req in
    let session_id = find_id Session.Id.of_string Field.Session req in
    fcn experiment_id session_id
  ;;

  let index =
    Session.Guard.Access.index
    |> experiment_effects
    |> Guardian.validate_generic ~any_id:true
  ;;

  let create =
    SessionCommand.Create.effects
    |> experiment_effects
    |> Guardian.validate_generic
  ;;

  let read =
    Session.Guard.Access.read |> combined_effects |> Guardian.validate_generic
  ;;

  let update =
    SessionCommand.Update.effects
    |> combined_effects
    |> Guardian.validate_generic
  ;;

  let delete =
    SessionCommand.Delete.effects
    |> combined_effects
    |> Guardian.validate_generic
  ;;

  let reschedule =
    SessionCommand.Reschedule.effects
    |> combined_effects
    |> Guardian.validate_generic
  ;;

  let cancel =
    SessionCommand.Cancel.effects
    |> combined_effects
    |> Guardian.validate_generic
  ;;

  let send_reminder =
    SessionCommand.SendReminder.effects
    |> combined_effects
    |> Guardian.validate_generic
  ;;

  let close =
    Cqrs_command.Assignment_command.SetAttendance.effects
    |> combined_effects
    |> Guardian.validate_generic
  ;;
end
