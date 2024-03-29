open Pool_common.Language

let account_suspension_notification = function
  | De -> Default_de.account_suspension_notification
  | En -> Default_en.account_suspension_notification
;;

let assignment_confirmation = function
  | De -> Default_de.assignment_confirmation
  | En -> Default_en.assignment_confirmation
;;

let assignment_session_change = function
  | De -> Default_de.assignment_session_change
  | En -> Default_en.assignment_session_change
;;

let contact_registration_attempt = function
  | De -> Default_de.contact_registration_attempt
  | En -> Default_en.contact_registration_attempt
;;

let email_verification = function
  | De -> Default_de.email_verification
  | En -> Default_en.email_verification
;;

let experiment_invitation = function
  | De -> Default_de.experiment_invitation
  | En -> Default_en.experiment_invitation
;;

let password_change = function
  | De -> Default_de.password_change
  | En -> Default_en.password_change
;;

let password_reset = function
  | De -> Default_de.password_reset
  | En -> Default_en.password_reset
;;

let phone_verification = function
  | De -> Default_de.phone_verification
  | En -> Default_en.phone_verification
;;

let profile_update_trigger = function
  | De -> Default_de.profile_update_trigger
  | En -> Default_en.profile_update_trigger
;;

let session_cancellation = function
  | De -> Default_de.session_cancellation
  | En -> Default_en.session_cancellation
;;

let session_reminder = function
  | De -> Default_de.session_reminder
  | En -> Default_en.session_reminder
;;

let session_reschedule = function
  | De -> Default_de.session_reschedule
  | En -> Default_en.session_reschedule
;;

let signup_verification = function
  | De -> Default_de.signup_verification
  | En -> Default_en.signup_verification
;;

let user_import = function
  | De -> Default_de.user_import
  | En -> Default_en.user_import
;;

let waiting_list_confirmation = function
  | De -> Default_de.waiting_list_confirmation
  | En -> Default_en.waiting_list_confirmation
;;

let ( @@@ ) constructors =
  CCList.flat_map (fun lang -> CCList.map (fun fcn -> fcn lang) constructors)
;;

let default_values_root = [ password_reset ] @@@ [ En; De ]

let default_values_tenant =
  [ account_suspension_notification
  ; assignment_confirmation
  ; assignment_session_change
  ; contact_registration_attempt
  ; email_verification
  ; experiment_invitation
  ; password_change
  ; password_reset
  ; phone_verification
  ; profile_update_trigger
  ; session_cancellation
  ; session_reminder
  ; session_reschedule
  ; signup_verification
  ; user_import
  ; waiting_list_confirmation
  ]
  @@@ [ En; De ]
;;
