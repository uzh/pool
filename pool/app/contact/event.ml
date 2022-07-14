module User = Pool_user
module Id = Pool_common.Id
module Database = Pool_database
open Entity

type create =
  { user_id : Id.t
  ; email : User.EmailAddress.t
  ; password : User.Password.t
  ; firstname : User.Firstname.t
  ; lastname : User.Lastname.t
  ; recruitment_channel : RecruitmentChannel.t
  ; terms_accepted_at : User.TermsAccepted.t
  ; language : Pool_common.Language.t option
  }
[@@deriving eq, show]

type update =
  { firstname : User.Firstname.t
  ; lastname : User.Lastname.t
  ; paused : User.Paused.t
  ; language : Pool_common.Language.t option
  }
[@@deriving eq, show]

let set_password
  : Database.Label.t -> t -> string -> string -> (unit, string) Lwt_result.t
  =
 fun pool { user; _ } password password_confirmation ->
  let open Lwt_result.Infix in
  Service.User.set_password
    ~ctx:(Pool_tenant.to_ctx pool)
    user
    ~password
    ~password_confirmation
  >|= ignore
;;

let has_terms_accepted pool (contact : t) =
  let%lwt last_updated = Settings.terms_and_conditions_last_updated pool in
  let terms_accepted_at =
    contact.terms_accepted_at |> User.TermsAccepted.value
  in
  CCOption.map (Ptime.is_later ~than:last_updated) terms_accepted_at
  |> CCOption.get_or ~default:false
  |> Lwt.return
;;

type event =
  | Created of create
  | FirstnameUpdated of t * User.Firstname.t
  | LastnameUpdated of t * User.Lastname.t
  | PausedUpdated of t * User.Paused.t
  | EmailUpdated of t * User.EmailAddress.t
  | PasswordUpdated of
      t * User.Password.t * User.Password.t * User.PasswordConfirmed.t
  | LanguageUpdated of t * Pool_common.Language.t
  | Verified of t
  | EmailVerified of t
  | TermsAccepted of t
  | Disabled of t
  | UnverifiedDeleted of t
  | AssignmentIncreased of t
  | ShowUpIncreased of t
[@@deriving eq, show, variants]

let handle_event pool : event -> unit Lwt.t =
  let ctx = Pool_tenant.to_ctx pool in
  function
  | Created contact ->
    let%lwt user =
      Service.User.create_user
        ~ctx
        ~id:(contact.user_id |> Id.value)
        ~name:(contact.lastname |> User.Lastname.value)
        ~given_name:(contact.firstname |> User.Firstname.value)
        ~password:(contact.password |> User.Password.to_sihl)
      @@ User.EmailAddress.value contact.email
    in
    { user
    ; recruitment_channel = contact.recruitment_channel
    ; terms_accepted_at = contact.terms_accepted_at
    ; language = contact.language
    ; paused = User.Paused.create false
    ; disabled = User.Disabled.create false
    ; verified = User.Verified.create None
    ; email_verified = User.EmailVerified.create None
    ; num_invitations = NumberOfInvitations.init
    ; num_assignments = NumberOfAssignments.init
    ; firstname_version = Pool_common.Version.create ()
    ; lastname_version = Pool_common.Version.create ()
    ; paused_version = Pool_common.Version.create ()
    ; language_version = Pool_common.Version.create ()
    ; created_at = Ptime_clock.now ()
    ; updated_at = Ptime_clock.now ()
    }
    |> Repo.insert pool
    |> CCFun.const Lwt.return_unit
  | FirstnameUpdated (contact, firstname) ->
    let%lwt _ =
      Service.User.update
        ~ctx
        ~given_name:(firstname |> User.Firstname.value)
        contact.user
    in
    Repo.update_version_for
      pool
      `Firstname
      (id contact, Pool_common.Version.increment contact.firstname_version)
  | LastnameUpdated (contact, lastname) ->
    let%lwt _ =
      Service.User.update
        ~ctx
        ~name:(lastname |> User.Lastname.value)
        contact.user
    in
    Repo.update_version_for
      pool
      `Lastname
      (id contact, Pool_common.Version.increment contact.lastname_version)
  | PausedUpdated (contact, paused) ->
    let%lwt () =
      Repo.update_paused
        pool
        { contact with
          paused
        ; paused_version = Pool_common.Version.increment contact.paused_version
        }
    in
    Lwt.return_unit
  | EmailUpdated (contact, email) ->
    let%lwt _ =
      Service.User.update
        ~ctx
        ~email:(Pool_user.EmailAddress.value email)
        contact.user
    in
    Lwt.return_unit
  | PasswordUpdated (person, old_password, new_password, confirmed) ->
    let old_password = old_password |> User.Password.to_sihl in
    let new_password = new_password |> User.Password.to_sihl in
    let new_password_confirmation =
      confirmed |> User.PasswordConfirmed.to_sihl
    in
    let%lwt _ =
      Service.User.update_password
        ~ctx
        ~password_policy:(CCFun.const (CCResult.pure ()))
        ~old_password
        ~new_password
        ~new_password_confirmation
        person.user
    in
    Lwt.return_unit
  | LanguageUpdated (contact, language) ->
    let%lwt () =
      Repo.update_language
        pool
        { contact with
          language = Some language
        ; language_version =
            Pool_common.Version.increment contact.language_version
        }
    in
    Lwt.return_unit
  | Verified contact ->
    Repo.update
      pool
      { contact with verified = Pool_user.Verified.create_now () }
  | EmailVerified contact ->
    let%lwt _ =
      Service.User.update ~ctx Sihl_user.{ contact.user with confirmed = true }
    in
    Repo.update
      pool
      { contact with email_verified = Pool_user.EmailVerified.create_now () }
  | TermsAccepted contact ->
    Repo.update
      pool
      { contact with terms_accepted_at = User.TermsAccepted.create_now () }
  | Disabled contact ->
    Repo.update pool { contact with disabled = User.Disabled.create true }
  | UnverifiedDeleted contact ->
    contact |> Entity.id |> Repo.delete_unverified pool
  | AssignmentIncreased contact ->
    Repo.update
      pool
      { contact with
        num_invitations =
          contact.num_invitations |> NumberOfInvitations.increment
      }
  | ShowUpIncreased contact ->
    Repo.update
      pool
      { contact with
        num_assignments =
          contact.num_assignments |> NumberOfAssignments.increment
      }
;;
