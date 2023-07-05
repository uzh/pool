open Pool_common.Message

module Data = struct
  let token = "123123"
  let password = "Password1!"
end

let get_or_failwith_pool_error = Test_utils.get_or_failwith_pool_error

let create_user_import ?(token = Data.token) user =
  let open User_import in
  let user_uuid =
    let open Pool_context in
    match user with
    | Contact contact ->
      Contact.(id contact |> Id.value |> Pool_common.Id.of_string)
    | Admin admin -> Admin.(id admin |> Id.value |> Pool_common.Id.of_string)
    | Guest -> failwith "Invalid user"
  in
  { user_uuid
  ; token = Token.create token |> get_or_failwith_pool_error
  ; confirmed_at = None
  ; notified_at = None
  ; reminded_at = None
  ; created_at = Pool_common.CreatedAt.create ()
  ; updated_at = Pool_common.UpdatedAt.create ()
  }
;;

let confirm_without_matching_password () =
  let contact =
    Test_utils.Model.create_contact ~with_terms_accepted:false ()
    |> Pool_context.contact
  in
  let user_import = create_user_import contact in
  let urlencoded =
    let open Field in
    [ Token |> show, [ Data.token ]
    ; Password |> show, [ Data.password ]
    ; PasswordConfirmation |> show, [ "Password2!" ]
    ]
  in
  let result =
    let open CCResult in
    let open Cqrs_command.User_import_command.ConfirmImport in
    urlencoded |> decode >>= handle (user_import, contact)
  in
  let expected = Error PasswordConfirmationDoesNotMatch in
  Test_utils.check_result expected result
;;

let confirm_as_contact () =
  let contact = Test_utils.Model.create_contact ~with_terms_accepted:false () in
  let user = contact |> Pool_context.contact in
  let user_import = create_user_import user in
  let urlencoded =
    let open Field in
    [ Token |> show, [ Data.token ]
    ; Password |> show, [ Data.password ]
    ; PasswordConfirmation |> show, [ Data.password ]
    ]
  in
  let result =
    let open CCResult in
    let open Cqrs_command.User_import_command.ConfirmImport in
    urlencoded |> decode >>= handle (user_import, user)
  in
  let expected =
    Ok
      [ Contact.ImportConfirmed
          ( contact
          , Pool_user.Password.create Data.password
            |> get_or_failwith_pool_error )
        |> Pool_event.contact
      ; User_import.Confirmed user_import |> Pool_event.user_import
      ]
  in
  Test_utils.check_result expected result
;;

let confirm_as_admin () =
  let user = Test_utils.Model.create_admin () in
  let admin =
    let open Pool_context in
    match user with
    | Admin admin -> admin
    | Guest | Contact _ -> failwith "Invalid user"
  in
  let user_import = create_user_import user in
  let urlencoded =
    let open Field in
    [ Token |> show, [ Data.token ]
    ; Password |> show, [ Data.password ]
    ; PasswordConfirmation |> show, [ Data.password ]
    ]
  in
  let result =
    let open CCResult in
    let open Cqrs_command.User_import_command.ConfirmImport in
    urlencoded |> decode >>= handle (user_import, user)
  in
  let expected =
    Ok
      [ Admin.ImportConfirmed
          ( admin
          , Pool_user.Password.create Data.password
            |> get_or_failwith_pool_error )
        |> Pool_event.admin
      ; User_import.Confirmed user_import |> Pool_event.user_import
      ]
  in
  Test_utils.check_result expected result
;;

let confirm_as_contact_integration _ () =
  let contact = Test_utils.Model.create_contact ~with_terms_accepted:false () in
  let user = contact |> Pool_context.contact in
  let user_import = create_user_import user in
  let urlencoded =
    let open Field in
    [ Token |> show, [ Data.token ]
    ; Password |> show, [ Data.password ]
    ; PasswordConfirmation |> show, [ Data.password ]
    ]
  in
  let%lwt () =
    let open CCResult in
    let open Cqrs_command.User_import_command.ConfirmImport in
    urlencoded
    |> decode
    >>= handle (user_import, user)
    |> get_or_failwith_pool_error
    |> Pool_event.handle_events Test_utils.Data.database_label
  in
  let%lwt contact =
    Contact.find Test_utils.Data.database_label (Contact.id contact)
    |> Lwt.map get_or_failwith_pool_error
  in
  let expected =
    Contact.
      { contact with
        import_pending = Pool_user.ImportPending.create false
      ; terms_accepted_at = Some (Pool_user.TermsAccepted.create_now ())
      }
  in
  let () = Alcotest.(check Test_utils.contact "succeeds" expected contact) in
  Lwt.return_unit
;;