module Testable = struct
  let contact_email = Settings.ContactEmail.(Alcotest.testable pp equal)
  let email_suffix = Settings.EmailSuffix.(Alcotest.testable pp equal)

  let inactive_user_disable_after =
    Settings.InactiveUser.DisableAfter.(Alcotest.testable pp equal)
  ;;

  let inactive_user_warning =
    Settings.InactiveUser.Warning.(Alcotest.testable pp equal)
  ;;

  let language = Pool_common.Language.(Alcotest.testable pp equal)

  let terms_and_conditions =
    Settings.TermsAndConditions.(Alcotest.testable pp equal)
  ;;
end

let database_label = Test_utils.Data.database_label

let check_contact_email _ () =
  let%lwt contact = Settings.find_contact_email database_label in
  let expected =
    Settings.ContactEmail.create "pool@econ.uzh.ch"
    |> Test_utils.get_or_failwith_pool_error
  in
  Alcotest.(
    check Testable.contact_email "contact email address" contact expected)
  |> Lwt.return
;;

let check_email_suffix _ () =
  let open Settings in
  let%lwt suffix = find_email_suffixes database_label in
  Alcotest.(
    check bool "has minimum one email suffix" (suffix |> CCList.is_empty) false)
  |> Lwt.return
;;

let check_inactive_user_disable_after _ () =
  let%lwt disable = Settings.find_inactive_user_disable_after database_label in
  let expected =
    Settings.InactiveUser.DisableAfter.create "5"
    |> Test_utils.get_or_failwith_pool_error
  in
  Alcotest.(
    check
      Testable.inactive_user_disable_after
      "disable inactive user after weeks"
      disable
      expected)
  |> Lwt.return
;;

let check_inactive_user_warning _ () =
  let%lwt warning = Settings.find_inactive_user_warning database_label in
  let expected =
    Settings.InactiveUser.Warning.create "7"
    |> Test_utils.get_or_failwith_pool_error
  in
  Alcotest.(
    check
      Testable.inactive_user_warning
      "inactive user warning after days"
      warning
      expected)
  |> Lwt.return
;;

let check_languages _ () =
  let%lwt language = Settings.find_languages database_label in
  Alcotest.(
    check
      (list Testable.language)
      "languages"
      language
      Pool_common.Language.[ En; De ])
  |> Lwt.return
;;

let check_terms_and_conditions _ () =
  let open Settings in
  let%lwt terms = find_terms_and_conditions database_label in
  let has_terms = terms |> CCList.is_empty |> not in
  Alcotest.(check bool "has terms and conditions" has_terms true) |> Lwt.return
;;

let update_terms_and_conditions _ () =
  let%lwt languages = Settings.find_languages database_label in
  let terms_and_conditions_text = "Terms and conditions" in
  let%lwt events =
    let open Utils.Lwt_result.Infix in
    let data =
      CCList.map
        (fun lang ->
          Pool_common.Language.show lang, [ terms_and_conditions_text ])
        languages
    in
    let result =
      Cqrs_command.Settings_command.UpdateTermsAndConditions.handle
        languages
        data
      |> Lwt_result.lift
    in
    let%lwt (_ : (unit Lwt.t, Pool_common.Message.error) result) =
      result >|+ Lwt_list.iter_s (Pool_event.handle_event database_label)
    in
    result
  in
  let expected =
    let open CCResult.Infix in
    let* terms_and_conditions =
      CCResult.flatten_l
        (CCList.map
           (fun l ->
             Settings.TermsAndConditions.create
               (l |> Pool_common.Language.show)
               terms_and_conditions_text)
           languages)
    in
    Ok
      [ Settings.TermsAndConditionsUpdated terms_and_conditions
        |> Pool_event.settings
      ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
  |> Lwt.return
;;

let login_after_terms_update _ () =
  let open Utils.Lwt_result.Infix in
  let open Pool_common.Message in
  let%lwt user = Integration_utils.ContactRepo.create () in
  let accepted =
    let contact =
      Contact.find_by_email database_label (Contact.email_address user)
    in
    let terms_agreed contact =
      let%lwt accepted = Contact.has_terms_accepted database_label contact in
      match accepted with
      | true -> Lwt.return_ok contact
      | false -> Lwt.return_error TermsAndConditionsNotAccepted
    in
    contact >|- CCFun.const (NotFound Field.Contact) >>= terms_agreed
  in
  let expected = Error TermsAndConditionsNotAccepted in
  accepted
  ||> fun accepted ->
  Alcotest.(
    check
      (result Test_utils.contact Test_utils.error)
      "succeeds"
      expected
      accepted)
;;
