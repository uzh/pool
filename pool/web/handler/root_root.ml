module HttpUtils = Http_utils
module Message = HttpUtils.Message
module Database = Pool_database

let create req =
  let result { Pool_context.database_label; _ } =
    let open Utils.Lwt_result.Infix in
    let open Pool_common.Message in
    let user () =
      Sihl.Web.Request.urlencoded Field.(Email |> show) req
      ||> CCOption.to_result EmailAddressMissingRoot
      >>= HttpUtils.validate_email_existance database_label
    in
    let tags = Logger.req req in
    let events () =
      let open CCResult.Infix in
      let%lwt urlencoded = Sihl.Web.Request.to_urlencoded req in
      urlencoded
      |> Cqrs_command.Root_command.Create.decode
      >>= Cqrs_command.Root_command.Create.handle ~tags
      |> Lwt_result.lift
    in
    let handle =
      Lwt_list.iter_s (Pool_event.handle_event ~tags Database.root)
    in
    let return_to_overview () =
      Http_utils.redirect_to_with_actions
        "/root/tenants"
        [ Message.set ~success:[ Created Field.Root ] ]
    in
    ()
    |> user
    >>= events
    >|- (fun err -> err, "/root/tenants/")
    |>> handle
    |>> return_to_overview
  in
  result |> HttpUtils.extract_happy_path req
;;

let toggle_status req =
  let open Utils.Lwt_result.Infix in
  let result { Pool_context.database_label; _ } =
    let id =
      let open Pool_common.Message.Field in
      HttpUtils.find_id Admin.Id.of_string Admin req
    in
    let tags = Logger.req req in
    let events user =
      Cqrs_command.Root_command.ToggleStatus.handle ~tags user
      |> Lwt_result.lift
    in
    let handle =
      Lwt_list.iter_s (Pool_event.handle_event ~tags database_label)
    in
    let return_to_overview () =
      Http_utils.redirect_to_with_actions
        "/root/tenants"
        [ Message.set ~success:[ Pool_common.Message.(Updated Field.Root) ] ]
    in
    id
    |> Admin.find Pool_database.root
    >>= events
    >|- (fun err -> err, "/root/tenants/")
    |>> handle
    |>> return_to_overview
  in
  result |> HttpUtils.extract_happy_path req
;;
