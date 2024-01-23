module HttpUtils = Http_utils
module Message = Pool_common.Message
module Url = Page.Admin.CustomFields.Url

let src = Logs.Src.create "handler.admin.custom_field_settings"
let create_layout req = General.create_tenant_layout req

let boolean_fields =
  Custom_field.boolean_fields |> CCList.map Message.Field.show
;;

let settings_path = "/admin/custom-fields/settings"

let show req =
  let open Utils.Lwt_result.Infix in
  let result ({ Pool_context.database_label; _ } as context) =
    Utils.Lwt_result.map_error (fun err -> err, "/admin/custom-fields")
    @@
    let%lwt contact_fields =
      Custom_field.(find_by_model database_label Model.Contact)
    in
    Page.Admin.CustomFieldSettings.show context contact_fields
    |> create_layout ~active_navigation:settings_path req context
    >|+ Sihl.Web.Response.of_html
  in
  result |> HttpUtils.extract_happy_path ~src req
;;

let update req =
  let open Utils.Lwt_result.Infix in
  let result { Pool_context.database_label; _ } =
    Utils.Lwt_result.map_error (fun err -> err, "/admin/custom-fields")
    @@
    let open Custom_field in
    let tags = Pool_context.Logger.Tags.req req in
    let%lwt selected =
      Sihl.Web.Request.urlencoded_list
        Pool_common.Message.Field.(array_key CustomField)
        req
    in
    let%lwt contact_fields = find_by_model database_label Model.Contact in
    let active, inactive =
      CCList.partition_filter_map
        (fun field ->
          let active = show_on_session_close_page field in
          CCList.find_opt
            (fun selected_id ->
              selected_id |> Id.of_string |> Id.equal (id field))
            selected
          |> function
          | Some (_ : string) when not active -> `Left field
          | None when active -> `Right field
          | Some (_ : string) | None -> `Drop)
        contact_fields
    in
    let events =
      Cqrs_command.Custom_field_settings_command.UpdateVisibilitySettings.handle
        ~tags
        ~active
        ~inactive
        ()
      |> Lwt_result.lift
    in
    let handle events =
      let%lwt () =
        Lwt_list.iter_s (Pool_event.handle_event ~tags database_label) events
      in
      Http_utils.redirect_to_with_actions
        settings_path
        [ HttpUtils.Message.set
            ~success:[ Pool_common.Message.(Updated Field.CustomField) ]
        ]
    in
    events |>> handle
  in
  result |> HttpUtils.extract_happy_path ~src req
;;

module Access : sig
  val show : Rock.Middleware.t
  val update : Rock.Middleware.t
end = struct
  module Command = Cqrs_command.Custom_field_settings_command
  module Guardian = Middleware.Guardian

  let show =
    Command.UpdateVisibilitySettings.effects |> Guardian.validate_admin_entity
  ;;

  let update =
    Command.UpdateVisibilitySettings.effects |> Guardian.validate_admin_entity
  ;;
end