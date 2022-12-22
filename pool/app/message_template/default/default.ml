open Pool_common.Language

let assignment_confirmation = function
  | De -> Default_de.assignment_confirmation
  | En -> Default_en.assignment_confirmation
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

let signup_verification = function
  | De -> Default_de.signup_verification
  | En -> Default_en.signup_verification
;;

let session_cancellation = function
  | De -> Default_de.session_cancellation
  | En -> Default_en.session_cancellation
;;

let session_reminder = function
  | De -> Default_de.session_reminder
  | En -> Default_en.session_reminder
;;

let ( @@@ ) constructors =
  CCList.flat_map (fun lang -> CCList.map (fun fcn -> fcn lang) constructors)
;;

let default_values_root = [ password_reset ] @@@ [ En; De ]

let default_values_tenant =
  [ assignment_confirmation
  ; email_verification
  ; experiment_invitation
  ; password_change
  ; password_reset
  ; signup_verification
  ; session_cancellation
  ; session_reminder
  ]
  @@@ [ En; De ]
;;