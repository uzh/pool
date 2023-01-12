module Contact_command = Cqrs_command.Contact_command
module Message = Pool_common.Message
module Field = Message.Field
module Language = Pool_common.Language

let check_result expected generated =
  Alcotest.(
    check
      (result (list Test_utils.event) Test_utils.error)
      "succeeds"
      expected
      generated)
;;

let contact_info email_address =
  email_address, "password", "Jane", "Doe", Some Language.En
;;

let tenant = Tenant_test.Data.full_tenant |> CCResult.get_exn

let confirmation_mail contact =
  let email =
    Contact.(contact |> email_address |> Pool_user.EmailAddress.value)
  in
  let open Message_template in
  let sender = "test@econ.uzh.ch" in
  let { email_subject; email_text; _ } =
    Test_utils.Model.create_message_template ()
  in
  Sihl_email.
    { sender
    ; recipient = email
    ; subject = email_subject |> EmailSubject.value
    ; text = ""
    ; html = Some (email_text |> EmailText.value)
    ; cc = []
    ; bcc = []
    }
;;

let sign_up_contact contact_info =
  let email_address, password, firstname, lastname, _ = contact_info in
  [ Field.(Email |> show), [ email_address ]
  ; Field.(Password |> show), [ password ]
  ; Field.(Firstname |> show), [ firstname ]
  ; Field.(Lastname |> show), [ lastname ]
  ]
;;

let create_contact verified contact_info =
  let email_address, password, firstname, lastname, language = contact_info in
  { Contact.user =
      Sihl_user.
        { id = Pool_common.Id.(create () |> value)
        ; email = email_address
        ; username = None
        ; name = Some lastname
        ; given_name = Some firstname
        ; password =
            password |> Sihl_user.Hashing.hash |> CCResult.get_or_failwith
        ; status =
            Sihl_user.status_of_string "active" |> CCResult.get_or_failwith
        ; admin = false
        ; confirmed = true
        ; created_at = Pool_common.CreatedAt.create ()
        ; updated_at = Pool_common.UpdatedAt.create ()
        }
  ; terms_accepted_at = Pool_user.TermsAccepted.create_now () |> CCOption.pure
  ; language
  ; experiment_type_preference = None
  ; paused = Pool_user.Paused.create false
  ; disabled = Pool_user.Disabled.create false
  ; verified = None
  ; email_verified =
      (if verified
      then Some (Ptime_clock.now () |> Pool_user.EmailVerified.create)
      else None)
  ; num_invitations = Contact.NumberOfInvitations.init
  ; num_assignments = Contact.NumberOfAssignments.init
  ; num_show_ups = Contact.NumberOfShowUps.init
  ; num_participations = Contact.NumberOfParticipations.init
  ; firstname_version = Pool_common.Version.create ()
  ; lastname_version = Pool_common.Version.create ()
  ; paused_version = Pool_common.Version.create ()
  ; language_version = Pool_common.Version.create ()
  ; experiment_type_preference_version = Pool_common.Version.create ()
  ; created_at = Pool_common.CreatedAt.create ()
  ; updated_at = Pool_common.UpdatedAt.create ()
  }
;;

let sign_up_not_allowed_suffix () =
  let allowed_email_suffixes =
    [ "gmail.com" ]
    |> CCList.map Settings.EmailSuffix.create
    |> CCResult.flatten_l
    |> CCResult.get_exn
  in
  let events =
    let open Contact_command.SignUp in
    "john@bluewin.com"
    |> contact_info
    |> sign_up_contact
    |> decode
    |> Pool_common.Utils.get_or_failwith
    |> handle ~allowed_email_suffixes tenant None
  in
  let expected =
    Error
      Message.(
        InvalidEmailSuffix
          (allowed_email_suffixes |> CCList.map Settings.EmailSuffix.value))
  in
  check_result expected events
;;

let sign_up () =
  let user_id = Pool_common.Id.create () in
  let terms_accepted_at =
    Pool_user.TermsAccepted.create_now () |> CCOption.pure
  in
  let ((email_address, password, firstname, lastname, language) as contact_info)
    =
    contact_info "john@gmail.com"
  in
  let events =
    let open CCResult in
    let open Contact_command.SignUp in
    let* allowed_email_suffixes =
      [ "gmail.com" ]
      |> CCList.map Settings.EmailSuffix.create
      |> CCResult.flatten_l
    in
    contact_info
    |> sign_up_contact
    |> decode
    |> Pool_common.Utils.get_or_failwith
    |> handle
         ~allowed_email_suffixes
         ~user_id
         ~terms_accepted_at
         tenant
         language
  in
  let expected =
    let email = email_address |> Pool_user.EmailAddress.of_string in
    let firstname = firstname |> Pool_user.Firstname.of_string in
    let lastname = lastname |> Pool_user.Lastname.of_string in
    let contact : Contact.create =
      { Contact.user_id
      ; email
      ; password =
          password
          |> Pool_user.Password.create
          |> Pool_common.Utils.get_or_failwith
      ; firstname
      ; lastname
      ; terms_accepted_at
      ; language
      }
    in
    Ok
      [ Contact.Created contact |> Pool_event.contact
      ; Email.Created
          ( email
          , user_id
          , firstname
          , lastname
          , language |> CCOption.get_exn_or "Test failed"
          , Email.Helper.layout_from_tenant tenant )
        |> Pool_event.email_verification
      ]
  in
  check_result expected events
;;

let delete_unverified () =
  let contact = "john@gmail.com" |> contact_info |> create_contact false in
  let events = Contact_command.DeleteUnverified.handle contact in
  let expected =
    Ok [ Contact.UnverifiedDeleted contact |> Pool_event.contact ]
  in
  check_result expected events
;;

let delete_verified () =
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let events = Contact_command.DeleteUnverified.handle contact in
  let expected = Error Message.EmailDeleteAlreadyVerified in
  check_result expected events
;;

let update_language () =
  let open CCResult in
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let language = Language.De in
  let version = 0 |> Pool_common.Version.of_int in
  let partial_update =
    Contact.PartialUpdate.(Language (version, Some language))
  in
  let events = partial_update |> Contact_command.Update.handle contact in
  let expected =
    Ok [ Contact.Updated (partial_update, contact) |> Pool_event.contact ]
  in
  check_result expected events
;;

let update_password () =
  let ((_, password, _, _, _) as contact_info) =
    "john@gmail.com" |> contact_info
  in
  let contact = contact_info |> create_contact true in
  let new_password = "testing" in
  let confirmation_mail = confirmation_mail contact in
  let events =
    Contact_command.UpdatePassword.(
      [ Field.(CurrentPassword |> show), [ password ]
      ; Field.(NewPassword |> show), [ new_password ]
      ; Field.(PasswordConfirmation |> show), [ new_password ]
      ]
      |> decode
      |> Pool_common.Utils.get_or_failwith
      |> handle
           ~password_policy:(CCFun.const (CCResult.pure ()))
           contact
           confirmation_mail)
  in
  let expected =
    Ok
      [ Contact.PasswordUpdated
          ( contact
          , password
            |> Pool_user.Password.create
            |> Pool_common.Utils.get_or_failwith
          , new_password
            |> Pool_user.Password.create
            |> Pool_common.Utils.get_or_failwith
          , new_password |> Pool_user.PasswordConfirmed.create )
        |> Pool_event.contact
      ; Email.Sent confirmation_mail |> Pool_event.email
      ]
  in
  check_result expected events
;;

let update_password_wrong_current_password () =
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let current_password = "something else" in
  let new_password = "short" in
  let confirmation_mail = confirmation_mail contact in
  let events =
    Contact_command.UpdatePassword.(
      [ Field.(CurrentPassword |> show), [ current_password ]
      ; Field.(NewPassword |> show), [ new_password ]
      ; Field.(PasswordConfirmation |> show), [ new_password ]
      ]
      |> decode
      |> Pool_common.Utils.get_or_failwith
      |> handle contact confirmation_mail)
  in
  let expected = Error Message.(Invalid Field.CurrentPassword) in
  check_result expected events
;;

let update_password_wrong_policy () =
  let ((_, password, _, _, _) as contact_info) =
    "john@gmail.com" |> contact_info
  in
  let contact = contact_info |> create_contact true in
  let new_password = "short" in
  let confirmation_mail = confirmation_mail contact in
  let events =
    Contact_command.UpdatePassword.(
      [ Field.(CurrentPassword |> show), [ password ]
      ; Field.(NewPassword |> show), [ new_password ]
      ; Field.(PasswordConfirmation |> show), [ new_password ]
      ]
      |> decode
      |> Pool_common.Utils.get_or_failwith
      |> handle contact confirmation_mail)
  in
  let expected = Error Message.PasswordPolicy in
  check_result expected events
;;

let update_password_wrong_confirmation () =
  let ((_, password, _, _, _) as contact_info) =
    "john@gmail.com" |> contact_info
  in
  let contact = contact_info |> create_contact true in
  let new_password = "testing" in
  let confirmed_password = "something else" in
  let confirmation_mail = confirmation_mail contact in
  let events =
    Contact_command.UpdatePassword.(
      [ Field.(CurrentPassword |> show), [ password ]
      ; Field.(NewPassword |> show), [ new_password ]
      ; Field.(PasswordConfirmation |> show), [ confirmed_password ]
      ]
      |> decode
      |> Pool_common.Utils.get_or_failwith
      |> handle
           ~password_policy:(CCFun.const (CCResult.pure ()))
           contact
           confirmation_mail)
  in
  let expected = Error Pool_common.Message.PasswordConfirmationDoesNotMatch in
  check_result expected events
;;

let request_email_validation () =
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let new_email = "john.doe@gmail.com" in
  let events =
    let open CCResult in
    let* allowed_email_suffixes =
      [ "gmail.com" ]
      |> CCList.map Settings.EmailSuffix.create
      |> CCResult.flatten_l
    in
    Contact_command.RequestEmailValidation.(
      new_email
      |> Pool_user.EmailAddress.create
      |> Pool_common.Utils.get_or_failwith
      |> handle ~allowed_email_suffixes tenant contact)
  in
  let expected =
    let email_layout = Email.Helper.layout_from_tenant tenant in
    Ok
      [ Email.Updated
          ( new_email |> Pool_user.EmailAddress.of_string
          , contact.Contact.user
          , contact.Contact.language
            |> CCOption.get_or ~default:Pool_common.Language.En
          , email_layout )
        |> Pool_event.email_verification
      ]
  in
  check_result expected events
;;

let request_email_validation_wrong_suffix () =
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let new_email = "john.doe@gmx.com" in
  let allowed_email_suffixes =
    [ "gmail.com" ]
    |> CCList.map Settings.EmailSuffix.create
    |> CCResult.flatten_l
    |> CCResult.get_exn
  in
  let events =
    Contact_command.RequestEmailValidation.(
      new_email
      |> Pool_user.EmailAddress.create
      |> Pool_common.Utils.get_or_failwith
      |> handle ~allowed_email_suffixes tenant contact)
  in
  let expected =
    Error
      Message.(
        InvalidEmailSuffix
          (allowed_email_suffixes |> CCList.map Settings.EmailSuffix.value))
  in
  check_result expected events
;;

let update_email () =
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let new_email = "john.doe@gmail.com" in
  let email_unverified =
    Email.Unverified
      { Email.address = new_email |> Pool_user.EmailAddress.of_string
      ; user = contact.Contact.user
      ; token = Email.Token.create "testing"
      ; created_at = Ptime_clock.now ()
      ; updated_at = Ptime_clock.now ()
      }
  in
  let events =
    let open CCResult in
    let open Cqrs_command.User_command in
    let* allowed_email_suffixes =
      [ "gmail.com" ]
      |> CCList.map Settings.EmailSuffix.create
      |> CCResult.flatten_l
    in
    email_unverified
    |> UpdateEmail.handle ~allowed_email_suffixes (Contact contact)
  in
  let expected =
    Ok
      [ Contact.EmailUpdated (contact, Email.address email_unverified)
        |> Pool_event.contact
      ; Email.EmailVerified email_unverified |> Pool_event.email_verification
      ]
  in
  check_result expected events
;;

let verify_email () =
  let email_address = "john@gmail.com" in
  let contact = email_address |> contact_info |> create_contact true in
  let email_unverified =
    Email.Unverified
      { Email.address = email_address |> Pool_user.EmailAddress.of_string
      ; user = contact.Contact.user
      ; token = Email.Token.create "testing"
      ; created_at = Ptime_clock.now ()
      ; updated_at = Ptime_clock.now ()
      }
  in
  let events =
    let open Cqrs_command.User_command in
    email_unverified |> VerifyEmail.handle (Contact contact)
  in
  let expected =
    Ok
      [ Contact.EmailVerified contact |> Pool_event.contact
      ; Email.EmailVerified email_unverified |> Pool_event.email_verification
      ]
  in
  check_result expected events
;;

let accept_terms_and_conditions () =
  let contact = "john@gmail.com" |> contact_info |> create_contact true in
  let events = Contact_command.AcceptTermsAndConditions.handle contact in
  let expected = Ok [ Contact.TermsAccepted contact |> Pool_event.contact ] in
  check_result expected events
;;
