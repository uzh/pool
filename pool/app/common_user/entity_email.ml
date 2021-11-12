module PoolError = Pool_common.Message

module Token = struct
  type t = string [@@deriving eq, show]

  let create m = m
  let value m = m
end

module Address = struct
  type t = string [@@deriving eq, show]

  let remove_whitespaces =
    let open Re in
    replace_string (space |> compile) ~by:""
  ;;

  let validate_characters email =
    let open Re in
    (* Checks for more than 1 character before and more than 2 characters after
       the @ sign *)
    let regex =
      seq [ repn any 1 None; char '@'; repn any 2 None ]
      |> whole_string
      |> compile
    in
    if Re.execp regex email
    then Ok email
    else Error PoolError.(Invalid EmailAddress)
  ;;

  let strip_email_suffix email =
    (* TODO check whether this is stable *)
    let tail = CCString.split_on_char '@' email |> CCList.tail_opt in
    CCOpt.bind tail CCList.head_opt
  ;;

  let validate_suffix
      (allowed_email_suffixes : Settings.EmailSuffix.t list option)
      email
    =
    match allowed_email_suffixes with
    | None -> Ok ()
    | Some allowed_email_suffixes ->
      (match strip_email_suffix email with
      (* TODO check whether this is really the case *)
      | None -> Error PoolError.EmailMalformed
      | Some suffix ->
        let open CCResult in
        let* suffix = suffix |> Settings.EmailSuffix.create in
        if CCList.mem
             ~eq:Settings.EmailSuffix.equal
             suffix
             allowed_email_suffixes
        then Ok ()
        else Error PoolError.(Invalid EmailSuffix))
  ;;

  let validate = validate_suffix
  let value m = m
  let create email = email |> remove_whitespaces |> validate_characters

  let schema () =
    Conformist.custom
      Pool_common.(Utils.schema_decoder create PoolError.EmailAddress)
      CCList.pure
      "email"
  ;;
end

module VerifiedAt = struct
  type t = Ptime.t [@@deriving eq, show]
end

type email_unverified =
  { address : Address.t
  ; token : Token.t
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }
[@@deriving eq, show]

type email_verified =
  { address : Address.t
  ; verified_at : VerifiedAt.t
  ; created_at : Pool_common.CreatedAt.t
  ; updated_at : Pool_common.UpdatedAt.t
  }
[@@deriving eq, show]

(* TODO hide private constructors if possible *)
(* Don't use these private constructors *)
(* They are needed so the typechecker understands they are disjoint *)
type unverified = private XUnverifiedP
type verified = private XVerifiedP

type _ t =
  | Unverified : email_unverified -> unverified t
  | Verified : email_verified -> verified t

(* Carries type information, is a type "witness" *)
type _ carrier =
  | UnverifiedC : unverified carrier
  | VerifiedC : verified carrier

let equal : type state. state t -> state t -> bool =
 fun m k ->
  match m, k with
  | Unverified one, Unverified two -> equal_email_unverified one two
  | Verified one, Verified two -> equal_email_verified one two
;;

let pp : type state. Format.formatter -> state t -> unit =
 fun formatter email ->
  match email with
  | Unverified m -> pp_email_unverified formatter m
  | Verified m -> pp_email_verified formatter m
;;

let show : type state. state t -> string = function
  | Unverified { address; _ } | Verified { address; _ } -> Address.show address
;;

let address : type state. state t -> string = function
  | Unverified { address; _ } | Verified { address; _ } -> Address.value address
;;

let token (Unverified email) = Token.value email.token

let create address token =
  Unverified
    { address
    ; token
    ; created_at = Ptime_clock.now ()
    ; updated_at = Ptime_clock.now ()
    }
;;

let verify (Unverified email) =
  Verified
    { address = email.address
    ; verified_at = Ptime_clock.now ()
    ; created_at = email.created_at
    ; updated_at = Ptime_clock.now ()
    }
;;
