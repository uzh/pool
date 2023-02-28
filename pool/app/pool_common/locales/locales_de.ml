open Entity_message

let rec field_to_string =
  let open Field in
  function
  | Admin -> "Administrator"
  | AdminHint -> "Hint für Administratoren"
  | AdminInputOnly -> "Eingabe nur durch Admins"
  | AdminViewOnly -> "Nur für Admins ersichtlich"
  | AllowUninvitedSignup -> "Einschreiben nicht eingeladener Kontakte erlauben"
  | Answer -> "Antwort"
  | AssetId -> "Anlagen Identifier"
  | Assignment -> "Anmeldung"
  | AssignmentCount -> "Anmeldungen"
  | Assignments -> "Anmeldungen"
  | Assistants -> "Assistenten"
  | Building -> "Gebäude"
  | CanceledAt -> "Abgesagt am"
  | City -> "Ort"
  | ClosedAt -> "Geschlossen am"
  | Comment -> "Kommentar"
  | Contact -> "Kontakt"
  | ContactEmail -> "Kontakt E-Mail Adresse"
  | Contacts -> "Kontakte"
  | CreatedAt -> "Erstellt am"
  | CurrentPassword -> "Aktuelles Passwort"
  | CustomField -> "Feld"
  | CustomFieldGroup -> "Gruppe"
  | CustomFieldGroups -> "Gruppen"
  | CustomFieldOption -> "Option"
  | CustomFieldOptions -> "Optionen"
  | CustomFields -> "Felder"
  | CustomHtmx (label, _) -> label
  | Database -> "Datenbank"
  | DatabaseLabel -> "Datenbanklabel"
  | DatabaseUrl -> "Datenbankurl"
  | Date -> "Datum"
  | DateTime -> "Datum und Uhrzeit"
  | DefaultLanguage -> "Standard Sprache"
  | Description -> "Beschreibung"
  | DirectRegistrationDisabled -> "Direkte Registrierung deaktiviert"
  | Disabled -> "Gesperrt"
  | Distribution -> "Verteilung"
  | DistributionField -> "Feld"
  | Duration -> "Dauer"
  | Email -> "E-Mail"
  | EmailAddress -> "E-Mail Adresse"
  | EmailAddressUnverified -> "Unverifizierte E-Mail Adresse"
  | EmailAddressVerified -> "Verifizierte E-Mail Adresse"
  | EmailSubject -> "E-Mail Betreff"
  | EmailSuffix -> "E-Mail Endung"
  | EmailText -> "E-Mail Text"
  | End -> "Ende"
  | Experiment -> "Experiment"
  | Experimenter -> "Experimenter"
  | ExperimentReminderLeadTime ->
    Format.asprintf "Experimentspezifische %s" (field_to_string LeadTime)
  | ExperimentType -> "Experimenttyp"
  | FieldType -> "Feldtyp"
  | File -> "Datei"
  | FileMapping -> "Datei zuweisung"
  | FileMimeType -> "Mime Typ"
  | Filename -> "Dateiname"
  | Filesize -> "Dateigrösse"
  | Filter -> "Filter"
  | Firstname -> "Vorname"
  | FollowUpSession -> "Folgesession"
  | Hint -> "Hint"
  | Host -> "Host"
  | I18n -> "Übersetzung"
  | Icon -> "Icon"
  | Id -> "ID"
  | InactiveUserDisableAfter -> "Deaktiviere inaktiven Benutzer nach"
  | InactiveUserWarning -> "Warnung an inaktiven Benutzer"
  | Input -> "Input"
  | Institution -> "Institution"
  | Interval -> "Interval"
  | Invitation -> "Einladung"
  | InvitationCount -> "Anz. Einladungen"
  | Invitations -> "Einladungen"
  | InvitationSubject -> "Einladungsbetreff"
  | InvitationText -> "Einladungstext"
  | Key -> "Schlüssel"
  | Label -> "Label"
  | Language -> "Sprache"
  | LanguageDe -> "Deutsch"
  | LanguageEn -> "Englisch"
  | LastError -> "Letzte Fehlernachricht"
  | LastErrorAt -> "Letzter Fehler"
  | Lastname -> "Nachname"
  | LastRunAt -> "Letzter Durchlauf"
  | LeadTime -> "Vorlaufzeit"
  | Limit -> "Limit"
  | Link -> "Link"
  | Location -> "Lokalität"
  | LogoType -> "Logo Typ"
  | Mailing -> "Versand"
  | MainSession -> "Hauptsession"
  | MarkedAsDeleted -> "Als gelöscht markiert"
  | MaxParticipants -> "Maximum an Teilnehmern"
  | MaxTries -> "Maximum an Versuchen"
  | MessageChannel -> "Nachrichtenkanal"
  | MessageTemplate -> "Nachrichtentemplate"
  | MessageTemplates -> "Nachrichtentemplates"
  | MinParticipants -> "Minimum an Teilnehmern"
  | Model -> "Modell"
  | Name -> "Name"
  | NewPassword -> "Neues Passwort"
  | NextRunAt -> "Nächster Versuch um"
  | Offset -> "Offset"
  | Operator -> "Operator"
  | Operators -> "Operatoren"
  | Order -> "Reihenfolge"
  | Overbook -> "Überbuchen"
  | OverriddenValue -> "Überschriebene Kontakt-Antwort"
  | Override -> "Überschreiben"
  | Page -> "Seite"
  | PageCount -> "Anzahl Seiten"
  | Participant | Participants -> "Teilnehmer"
  | ParticipantCount -> "Teilnehmer"
  | Participated -> "teilgenommen"
  | PartnerLogos -> "Partner logos"
  | Password -> "Passwort"
  | PasswordConfirmation -> "Passwort wiederholen"
  | Paused -> "Pausiert"
  | PlainText -> "Klartext"
  | Predicate -> "Prädikat"
  | Profile -> "Profil"
  | PublicTitle -> "Öffentlicher Titel"
  | PublishedAt -> "Veröffentlicht"
  | Query -> "Query"
  | Queue -> "Warteschlange"
  | RandomOrder -> "Wähle die Kontakte in zufälliger Reihenfolge."
  | Rate -> "Höchstrate"
  | Reason -> "Grund"
  | RegistrationDisabled -> "Registrierung deaktiviert"
  | Required -> "Benötigt"
  | ResentAt -> "Erneut verschickt"
  | Role -> "Rolle"
  | Room -> "Raum"
  | Root -> "Root"
  | ScheduledTime -> "Geplante Zeit"
  | ScheduledTimeSpan -> "Wiederholungs Interval"
  | Search -> "Suche"
  | SentAt -> "Verschickt am"
  | Session -> "Session"
  | Sessions -> "Sessions"
  | Setting -> "Einstellung"
  | ShowUp -> "Anwesend"
  | ShowUpCount -> "Anwesende"
  | SMS -> "SMS"
  | SmsText -> "SMS Text"
  | Smtp -> "SMTP"
  | SmtpLabel -> "Label"
  | SmtpMechanism -> "Authentifizierungsmechanismus"
  | SmtpPassword -> "Passwort"
  | SmtpPort -> "Port"
  | SmtpProtocol -> "Protokoll"
  | SmtpServer -> "Server"
  | SmtpUsername -> "Benutzername"
  | SortOrder -> "Sortierung"
  | Start -> "Start"
  | Status -> "Status"
  | Street -> "Strasse"
  | Styles -> "Styles"
  | Tag -> "Tag"
  | Template -> "Template"
  | Tenant -> "Tenant"
  | TenantDisabledFlag -> "Deaktiviert"
  | TenantId -> "Tenant Identifier"
  | TenantLogos -> "Tenant Logos"
  | TenantMaintenanceFlag -> "Wartungsflag"
  | TenantPool -> "Tenant Pool"
  | TermsAccepted -> "Akzeptieren"
  | TermsAndConditions -> "Teilnahmebedingungen"
  | Time -> "Uhrzeit"
  | TimeSpan -> "Zeitspanne"
  | Title -> "Titel"
  | Token -> "Token"
  | Translation -> "Übersetzung"
  | Tries -> "Versuche"
  | TriggerProfileUpdateAfter -> "Aufforderung zur Kontrolle des Profils"
  | Url -> "Url"
  | User -> "Benutzer"
  | Validation -> "Validierung"
  | Value -> "Wert"
  | Version -> "Version"
  | Virtual -> "Virtuell"
  | WaitingList -> "Warteliste"
  | Zip -> "PLZ"
;;

let info_to_string : info -> string = function
  | Info s -> s
;;

let success_to_string : success -> string = function
  | AddedToWaitingList -> "Sie wurden der Warteliste hinzugefügt."
  | AssignmentCreated -> "Sie wurden erfolgreich angemeldet."
  | Canceled field ->
    field_message "" (field_to_string field) "wurde erfolgreich abgesagt."
  | Closed field ->
    field_message "" (field_to_string field) "wurde erfolgreich geschlossen."
  | Created field ->
    field_message "" (field_to_string field) "wurde erfolgreich erstellt."
  | Deleted field ->
    field_message "" (field_to_string field) "wurde erfolgreich gelöscht."
  | EmailConfirmationMessage ->
    "Eine E-Mail wurde an deine E-Mail Adresse zur Verifizierung gesendet, \
     falls die angegebene E-Mail Adresse noch verfügbar ist."
  | EmailVerified -> "E-Mail erfolgreich verifiziert."
  | FileDeleted -> "File wurde erfolgreich gelöscht."
  | MarkedAsDeleted field ->
    field_message "" (field_to_string field) "wurde als gelöscht markiert."
  | PasswordChanged -> "Passwort wurde geändert."
  | PasswordReset -> "Passwort ist zurückgesetzt, du kannst dich nun einloggen."
  | PasswordResetSuccessMessage ->
    "Falls ein Account zu der von dir eingegebenen E-Mail Adresse existiert,  \
     wird dir ein E-Mail mit einem Link zur Passwort zurücksetzung gesendet."
  | Published field ->
    field_message "" (field_to_string field) "wurde erfolgreich veröffentlicht."
  | RemovedFromWaitingList -> "Sie wurden von der Warteliste entfernt."
  | Rescheduled field ->
    field_message "" (field_to_string field) "wurden erfolgreich verschoben."
  | RoleAssigned -> "Rolle wurde zugewiesen."
  | RoleUnassigned -> "Rolle wurde entzogen."
  | SentList field ->
    field_message "" (field_to_string field) "wurden erfolgreich verschickt."
  | SettingsUpdated -> "Die Einstellungen wurden erfolgreich gespeichert."
  | SmtpConfigurationAdded ->
    "Die SMTP Konfiguration wurde erfolgreich hinzugefügt."
  | SmtpDetailsUpdated ->
    "Die SMTP Einstellungen wurden erfolgreich gespeichert."
  | SmtpPasswordUpdated -> "Das SMTP Passwort wurde erfolgreich gespeichert."
  | Stopped field ->
    field_message "" (field_to_string field) "wurde erfolgreich gestoppt."
  | TenantUpdateDatabase ->
    "Datenbank Informationen wurden erfolgreich upgedated."
  | TenantUpdateDetails -> "Tenant wurde erfolgreich upgedated."
  | Updated field ->
    field_message "" (field_to_string field) "wurde erfolgreich upgedated."
;;

let warning_to_string : warning -> string = function
  | Warning string -> string
;;

let rec error_to_string = function
  | AccessDenied -> "Zugriff verweigert"
  | AccessDeniedMessage ->
    "Der Zugriff auf die gewünschte Seite ist nicht möglich."
  | AllLanguagesRequired field ->
    field_message
      "Bitte geben Sie '"
      (field |> field_to_string |> CCString.trim)
      "' in allen Sprachen an."
  | AlreadyInPast ->
    "Mindestens der Startzeitpunkt liegt bereits in der Vergangenheit."
  | AlreadySignedUpForExperiment ->
    "Sie haben sich für dieses Experiment bereits angemeldet."
  | AlreadyPublished field ->
    field_message
      ""
      (field |> field_to_string |> CCString.trim)
      "wurde bereits veröffentlich."
  | AssignmentIsCanceled -> "Anmeldung wurde abgesagt."
  | AlreadyStarted ->
    "Bereits gestarted oder beendet, aktion nicht mehr möglich."
  | AlreadyInvitedToExperiment names ->
    Format.asprintf
      "Die folgenden Kontakte wurden bereits zu diesem Experiment eingeladen: \
       %s"
      (CCString.concat ", " names)
  | Authorization message ->
    field_message "Autorisierung nicht möglich: " message ""
  | Conformist errs ->
    CCList.map
      (fun (field, err) ->
        Format.asprintf
          "%s: %s"
          (field_to_string field |> CCString.capitalize_ascii)
          (error_to_string err))
      errs
    |> CCString.concat "\n"
  | ConformistModuleErrorType -> failwith "Do not use"
  | ContactSignupInvalidEmail ->
    "Bitte eine valide und nicht bereits verwendete E-Mail Adresse verwenden."
  | ContactUnconfirmed -> "Teilnehmer noch nicht verifiziert!"
  | CustomFieldTypeChangeNotAllowed ->
    "Sie können den Typ des Feldes nicht ändern."
  | Decode field ->
    field_message
      ""
      (field_to_string field)
      "konnte nicht entschlüsselt werden."
  | DecodeAction -> "Die Aktion konnte nicht gefunden werden."
  | DirectRegistrationIsDisabled ->
    "Sie können sich nicht selbst für dieses Experiment anmelden."
  | Disabled field ->
    field_message "" (field_to_string field) "ist deaktiviert."
  | EmailAddressMissingAdmin -> "Bitte Admin E-Mail Adresse angeben."
  | EmailAddressMissingRoot -> "Bitte Root E-Mail Adresse angeben."
  | EmailAlreadyInUse -> "E-Mail Adresse wird bereits verwendet."
  | EmailDeleteAlreadyVerified ->
    "E-Mail Adresse ist bereits verifiziert, kann nicht gelöscht werden."
  | EmailMalformed -> "Fehlerhafte E-Mail Adresse"
  | EndBeforeStart -> "Das Ende liegt vor oder dem Start."
  | ExperimentSessionCountNotZero ->
    "Es existieren Sessions zu diesem Experiment. Es kann nicht gelöscht  \
     werden."
  | FieldRequiresCheckbox (field, required) ->
    Format.asprintf
      "Die Option \"%s\" benötigt \"%s\"."
      (field_to_string field)
      (field_to_string required)
  | FilterMustNotContainTemplate -> "Filter darf keine Template enthalten."
  | FilterAndOrMustNotBeEmpty ->
    "'And' und 'Or' Prädikate dürfen nicht leer sein."
  | FilterListValueMustNotBeEmpty ->
    "Es muss mindestens eine Option angewählt werden."
  | FollowUpIsEarlierThanMain ->
    "Folgesession kann nicht vor Hauptsession starten."
  | HtmxVersionNotFound field ->
    Format.asprintf "Version von '%s' konnte nicht gefunden werden." field
  | Invalid field -> field_message "" (field_to_string field) "ist ungültig!"
  | InvalidEmailSuffix suffixes ->
    Format.asprintf
      "%s Die folgenden E-Mail-Endungen sind erlaubt: %s"
      (error_to_string (Invalid Field.EmailSuffix))
      (CCString.concat ", " suffixes)
  | InvalidJson exn -> Format.asprintf "Ungültiges Json: %s" exn
  | InvalidOptionSelected -> "Ungültige Option ausgewählt."
  | InvalidHtmxRequest -> "Ungültige Anfrage."
  | IsMarkedAsDeleted field ->
    field_message
      ""
      (field |> field_to_string |> CCString.trim)
      "wurde als gelöscht markiert."
  | LoginProvideDetails -> "Bitte Email Adresse und Passwort eintragen."
  | MeantimeUpdate field ->
    field_message
      ""
      (field_to_string field)
      "wurde in der Zwischenzeit bearbeitet!"
  | NegativeAmount -> "Hat negative Anzahl!"
  | NoOptionSelected field ->
    field_message "Bitte mindestens eine" (field_to_string field) "auswählen."
  | NotADatetime (time, err) ->
    Format.asprintf "%s: '%s' ist kein valides Datum." err time
  | NotANumber field -> Format.asprintf "'%s' ist keine Nummer." field
  | NoTenantsRegistered ->
    "Es sind keine Tenants auf der Root Datenbank registriert!"
  | NotEligible -> "Sie sind nicht befugt, diese Aktuion durchzuführen."
  | NotFound field ->
    field_message "" (field_to_string field) "konnte nicht gefunden werden!"
  | NotFoundList (field, items) ->
    field_message
      "Folgende"
      (field_to_string field)
      (Format.asprintf
         "konnten nicht gefunden werden: %s"
         (CCString.concat "," items))
  | NotHandled field ->
    Format.asprintf "Feld '%s' wird nicht verarbeitet." field
  | NotInTimeRange -> "Nicht im angegebenen Zeitfenster."
  | NoValue -> "Kein Wert angegeben"
  | NumberMax i -> Format.asprintf "Darf nicht grösser als %i sein." i
  | NumberMin i -> Format.asprintf "Darf nicht kleiner als %i sein." i
  | Or (err1, err2) ->
    CCFormat.asprintf
      "%s oder %s"
      (error_to_string err1)
      (err2 |> error_to_string |> CCString.uncapitalize_ascii)
  | PasswordConfirmationDoesNotMatch ->
    "Passwortbestätigung stimmt nicht mit dem neuen Passwort überein."
  | PasswordPolicy -> "Passwort stimmt nicht mit der benötigten Policy überein!"
  | PasswordResetFailMessage ->
    "Falls ein Account zu der von dir eingegebenen E-Mail Adresse existiert,  \
     wird dir ein E-Mail mit einem Link zur Passwort zurücksetzung gesendet."
  | PasswordResetInvalidData -> "Ungültiges Token oder Passwort."
  | PoolContextNotFound -> "Kontext konnte nicht gefunden werden."
  | PickMessageChannel ->
    "Kein Nachrichtenkanal wurde ausgewählt für die Benachrichtigung der \
     Kontakte."
  | QueryNotCompatible (f1, f2) ->
    Format.asprintf
      "%s ist nicht kompatibel mit %s."
      (field_to_string f1)
      (field_to_string f2)
  | ReadOnlyModel -> "Model ausschliesslich um von der Datenbank zu lesen!"
  | RegistrationDisabled -> "Registrierung ist deaktiviert."
  | RequestRequiredFields -> "Bitte alle notwendigen Felder ausfüllen."
  | RequiredFieldsMissing ->
    "Bitte beantworten Sie die folgenden Fragen um fortzufahren."
  | Retrieve field ->
    field_message "" (field_to_string field) "konnte nicht gefunden werden."
  | SessionFullyBooked -> "Session ist ausgebucht"
  | SessionHasAssignments ->
    "Es existieren bereits Anmeldungen für diese Session. Sie kann nicht \
     gelöscht werden."
  | SessionHasFollowUps ->
    "Es existieren bereits Folgesessions für diese Session. Sie kann nicht \
     gelöscht werden."
  | SessionInvalid -> "Ungültige Session, bitte erneut einloggen."
  | SessionRegistrationViaParent -> "Einschreibung via Hauptsession."
  | SessionTenantNotFound ->
    "Auf unserer Seite ist etwas schief gegangen, bitte später nochmals  \
     versuchen. Falls der Fehler mehrmals auftritt, bitte den Adminstrator  \
     kontaktieren."
  | SessionAlreadyCanceled date ->
    CCFormat.asprintf "Diese Session wurde bereits abgesagt am %s." date
  | SessionAlreadyClosed date ->
    CCFormat.asprintf "Diese Session wurde bereits geschlossen am %s." date
  | SessionInPast -> "Diese Session ist beendet."
  | SessionNotStarted -> "Diese Session kann noch nicht geschlossen werden."
  | Smaller (field1, field2) ->
    Format.asprintf
      "%s kleiner als %s"
      (field_to_string field1)
      (field_to_string field2)
  | TerminatoryTenantError | TerminatoryRootError ->
    "Bitte versuchen Sie es später erneut."
  | TerminatoryTenantErrorTitle | TerminatoryRootErrorTitle ->
    "Ein Fehler is aufgetreten."
  | TermsAndConditionsMissing ->
    "Die Teilnamhebedingungen müssen zuerst erfasst werden."
  | TermsAndConditionsNotAccepted ->
    "Die Teilnahmebedingungen sind noch nicht akzeptiert."
  | TextLengthMax i -> Format.asprintf "Darf nicht länger als %i sein." i
  | TextLengthMin i -> Format.asprintf "Darf nicht kürzer als %i sein." i
  | TimeInPast -> "Zeitpunkt liegt in der Vergangenheint!"
  | TimeSpanPositive -> "Zeitspanne muss grösser als 0 sein!"
  | TokenAlreadyUsed -> "Das Token wurde bereits verwendet."
  | TokenInvalidFormat -> "Ungültiges Token Format!"
  | Undefined field ->
    field_message "" (field_to_string field) "ist undefiniert."
  | WriteOnlyModel -> "Model ausschliesslich zum auf die Datenbank schreiben!"
;;

let format_submit submit field =
  let field_opt_message f =
    f |> CCOption.map field_to_string |> CCOption.value ~default:""
  in
  field_message (field_opt_message field) submit ""
;;

let control_to_string = function
  | Accept field -> format_submit "akzeptieren" field
  | Add field -> format_submit "hinzufügen" field
  | AddToWaitingList -> "Ich möchte mich zur Warteliste hinzufügen"
  | Ascending -> "aufsteigend"
  | Apply -> "anwenden"
  | Assign field -> format_submit "zuweisen" field
  | Back -> format_submit "zurück" None
  | Cancel field -> format_submit "absagen" field
  | Choose field -> format_submit "wählen" field
  | Close field -> format_submit "schliessen" field
  | Create field -> format_submit "erstellen" field
  | Decline -> format_submit "ablehnen" None
  | Delete field -> format_submit "löschen" field
  | Descending -> "absteigend"
  | Disable -> format_submit "deaktivieren" None
  | Duplicate field -> format_submit "duplizieren" field
  | Edit field -> format_submit "bearbeiten" field
  | Enable -> format_submit "aktivieren" None
  | Enroll -> format_submit "einschreiben" None
  | Filter field -> format_submit "filtern" field
  | Login -> format_submit "login" None
  | Manage field -> format_submit "manage" (Some field)
  | MarkAsDeleted -> format_submit "als gelöscht markieren" None
  | More -> "mehr"
  | NextPage -> "weiter"
  | PleaseSelect -> "bitte wählen"
  | PreviousPage -> "zurück"
  | Publish field -> format_submit "veröffentlichen" field
  | Register -> format_submit "einschreiben" None
  | RemoveFromWaitingList -> "Ich möchte mich von der Warteliste austragen"
  | Reschedule field -> format_submit "verschieben" field
  | ResetPlainText ->
    Format.asprintf
      "%s zu formatiertem '%s' zurücksetzen"
      (field_to_string Field.PlainText)
      (field_to_string Field.EmailText)
  | Resend field -> format_submit "erneut senden" field
  | Reset -> "zurücksetzen"
  | Save field -> format_submit "speichern" field
  | SelectAll field -> format_submit "alle auswählen" field
  | SelectFilePlaceholder -> format_submit "datei auswählen.." None
  | Send field -> format_submit "senden" field
  | SendResetLink -> format_submit "link senden" None
  | Show -> "anzeigen"
  | SignUp -> format_submit "anmelden" None
  | Stop field -> format_submit "stoppen" field
  | ToggleAll -> "alle umschalten"
  | Unassign field -> format_submit "entfernen" field
  | Update field -> format_submit "aktualisieren" field
  | UpdateOrder -> "Reihenfolge anpassen"
;;

let to_string = function
  | Message string -> string
  | PageNotFoundMessage -> "Die Seite konnte nicht gefunden werden."
;;
