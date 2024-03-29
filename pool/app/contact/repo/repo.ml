let find = Repo_sql.find
let find_admin_comment = Repo_sql.find_admin_comment
let find_multiple = Repo_sql.find_multiple
let find_by_email = Repo_sql.find_by_email
let find_all = Repo_sql.find_all
let find_to_trigger_profile_update = Repo_sql.find_to_trigger_profile_update
let insert = Repo_sql.insert
let update = Repo_sql.update
let delete_unverified = Repo_sql.delete_unverified
let update_profile_updated_triggered = Repo_sql.update_profile_updated_triggered

let should_send_registration_attempt_notification =
  Repo_sql.should_send_registration_attempt_notification
;;

let set_registration_attempt_notification_sent_at =
  Repo_sql.set_registration_attempt_notification_sent_at
;;

let add_cell_phone = Repo_sql.add_cell_phone

let find_cell_phone_verification_by_contact =
  Repo_sql.find_cell_phone_verification_by_contact
;;

let find_cell_phone_verification_by_contact_and_code =
  Repo_sql.find_cell_phone_verification_by_contact_and_code
;;

let find_full_cell_phone_verification_by_contact =
  Repo_sql.find_full_cell_phone_verification_by_contact
;;

let delete_unverified_cell_phone = Repo_sql.delete_unverified_cell_phone
let update_sign_in_count = Repo_sql.update_sign_in_count
