open Utils.Lwt_result.Infix
module HttpUtils = Http_utils
module Message = HttpUtils.Message
module Field = Pool_common.Message.Field

let src = Logs.Src.create "handler.admin.contacts.tags"
let contact_id = HttpUtils.find_id Contact.Id.of_string Field.Contact

let handle_tag action req =
  let tags = Pool_context.Logger.Tags.req req in
  let path =
    contact_id req |> Contact.Id.value |> Format.asprintf "/admin/contacts/%s"
  in
  let%lwt urlencoded =
    Sihl.Web.Request.to_urlencoded req ||> HttpUtils.remove_empty_values
  in
  let result { Pool_context.database_label; _ } =
    Lwt_result.map_error (fun err -> err, path)
    @@ let* contact =
         HttpUtils.get_field_router_param req Field.Contact
         |> Pool_common.Id.of_string
         |> Contact.find database_label
       in
       let decode, handle, message =
         match action with
         | `Assign ->
           let open Cqrs_command.Tags_command.AssignTagToContact in
           decode, handle, Pool_common.Message.TagAssigned
         | `Remove ->
           let open Cqrs_command.Tags_command.RemoveTagFromContact in
           decode, handle, Pool_common.Message.TagRemoved
       in
       let* events =
         let* tag_uuid = decode urlencoded |> Lwt_result.lift in
         let* (_ : Tags.t) = Tags.(find database_label tag_uuid) in
         handle ~tags contact tag_uuid |> Lwt_result.lift
       in
       let handle =
         Lwt_list.iter_s (Pool_event.handle_event ~tags database_label)
       in
       let return_to_overview () =
         HttpUtils.redirect_to_with_actions
           path
           [ Message.set ~success:[ message ] ]
       in
       events |> handle >|> return_to_overview |> Lwt_result.ok
  in
  result |> HttpUtils.extract_happy_path ~src req
;;

let assign_tag = handle_tag `Assign
let remove_tag = handle_tag `Remove