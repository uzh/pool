module I18nCommand = Cqrs_command.I18n_command
module SettingsCommand = Cqrs_command.Settings_command
module Common = Pool_common

let database_label = Test_utils.Data.database_label

let create () =
  let events =
    let open CCResult.Infix in
    [ "key", [ "confirmation_subject" ]
    ; "language", [ "EN" ]
    ; "content", [ "Subject" ]
    ]
    |> I18nCommand.Create.decode
    >>= I18nCommand.Create.handle
  in
  let expected =
    let open CCResult in
    let open I18n in
    let* key = Key.create "confirmation_subject" in
    let* language = Pool_common.Language.of_string "EN" in
    let* content = Content.create "Subject" in
    let create = { key; language; content } in
    Ok [ I18n.Created create |> Pool_event.i18n ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
;;

let update_terms_and_conditions () =
  let languages = Pool_common.Language.[ En; De ] in
  let events =
    [ "EN", [ "Terms and Conditions" ]; "DE", [ "Nutzungsbedingungen" ] ]
    |> Cqrs_command.Settings_command.UpdateTermsAndConditions.handle languages
  in
  let expected =
    let open CCResult in
    let* terms =
      [ "EN", "Terms and Conditions"; "DE", "Nutzungsbedingungen" ]
      |> CCList.map Settings.TermsAndConditions.create
      |> CCResult.flatten_l
    in
    Ok [ Settings.TermsAndConditionsUpdated terms |> Pool_event.settings ]
  in
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      events)
;;
