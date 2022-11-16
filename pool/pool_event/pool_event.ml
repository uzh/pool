(* All events that are possible in the whole system *)
type t =
  | Admin of Admin.event
  | Assignment of Assignment.event
  | Contact of Contact.event
  | CustomField of Custom_field.event
  | Database of Database.event
  | Email of Email.event
  | EmailVerification of Email.verification_event
  | Filter of Filter.event
  | Experiment of Experiment.event
  | Guard of Guard.event
  | I18n of I18n.event
  | Invitation of Invitation.event
  | Mailing of Mailing.event
  | PoolLocation of Pool_location.event
  | PoolTenant of Pool_tenant.event
  | Root of Root.event
  | Session of Session.event
  | Settings of Settings.event
  | Tenant of Tenant.event
  | WaitingList of Waiting_list.event
[@@deriving eq, show]

let admin events = Admin events
let assignment events = Assignment events
let contact events = Contact events
let custom_field events = CustomField events
let database events = Database events
let email events = Email events
let email_verification events = EmailVerification events
let experiment events = Experiment events
let filter events = Filter events
let guard events = Guard events
let i18n events = I18n events
let invitation events = Invitation events
let mailing events = Mailing events
let pool_location events = PoolLocation events
let pool_tenant events = PoolTenant events
let root events = Root events
let session events = Session events
let settings events = Settings events
let tenant events = Tenant events
let waiting_list events = WaitingList events

let handle_event pool event =
  match event with
  | Admin event -> Admin.handle_event pool event
  | Assignment event -> Assignment.handle_event pool event
  | Contact event -> Contact.handle_event pool event
  | CustomField event -> Custom_field.handle_event pool event
  | Database event -> Database.handle_event pool event
  | Email event -> Email.handle_event pool event
  | EmailVerification event -> Email.handle_verification_event pool event
  | Experiment event -> Experiment.handle_event pool event
  | Filter event -> Filter.handle_event pool event
  | Guard event -> Guard.handle_event pool event
  | I18n event -> I18n.handle_event pool event
  | Invitation event -> Invitation.handle_event pool event
  | Mailing event -> Mailing.handle_event pool event
  | PoolLocation event -> Pool_location.handle_event pool event
  | PoolTenant event -> Pool_tenant.handle_event pool event
  | Root event -> Root.handle_event pool event
  | Session event -> Session.handle_event pool event
  | Settings event -> Settings.handle_event pool event
  | Tenant event -> Tenant.handle_event pool event
  | WaitingList event -> Waiting_list.handle_event pool event
;;

let handle_events pool = Lwt_list.iter_s (handle_event pool)
