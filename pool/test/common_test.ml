module Data = struct
  let sender = "test@econ.uzh.ch"
  let recipient = "it@econ.uzh.ch"
  let subject = "test interceptor"

  let body =
    "Dear tester,\n\n\
     this mail is generated by pool tool test stage.\n\n\
     Best regards\n\
     Pipeline ;-)"
  ;;

  let create_email () = Sihl_email.create ~sender ~recipient ~subject body
end

let validate_email _ () =
  let open Email.Service in
  let open Smtp in
  let email = Data.create_email () in
  let smtp_auth_id = None in
  let { Email.email; _ } =
    Email.{ email; smtp_auth_id }
    |> intercept_prepare
    |> CCResult.get_or_failwith
  in
  let msg = "Missing 'TEST_EMAIL' env variable." in
  let%lwt { subject; _ } =
    prepare ?smtp_auth_id Test_utils.Data.database_label email
  in
  Alcotest.(
    check
      string
      "intercepted subject"
      subject
      (Format.asprintf
         "[Pool Tool] %s (original to: %s)"
         Data.subject
         Data.recipient));
  Alcotest.(
    check
      string
      "intercepted recipient"
      email.Sihl_email.recipient
      (Sihl.Configuration.read_string "TEST_EMAIL" |> CCOption.get_exn_or msg));
  Lwt.return_unit
;;
