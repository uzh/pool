module Common = Pool_common
module Message = Common.Message
module Dynparam = Utils.Database.Dynparam

module Column = struct
  type t = Common.Message.Field.t * string [@@deriving eq, show]

  let field m = fst m
  let to_sql m = snd m
  let create_list lst = lst
  let create m = m

  let to_query_parts (field, _value) =
    [ Common.Message.Field.Order, Common.Message.Field.show field ]
  ;;
end

module Pagination = struct
  module Limit = struct
    include Common.Model.Integer

    let default = 20
    let field = Message.Field.Limit
    let create m = if m >= 0 then Ok m else Error (Message.Invalid field)
    let schema = schema field create
  end

  module Page = struct
    include Common.Model.Integer

    let default = 1
    let field = Message.Field.Page
    let create m = if m > 0 then Ok m else Error (Message.Invalid field)
    let schema = schema field create
  end

  module PageCount = struct
    include Common.Model.Integer

    let field = Message.Field.PageCount
    let create m = if m >= 0 then Ok m else Error (Message.Invalid field)
    let schema = schema field create
  end

  type t =
    { limit : Limit.t
    ; page : Page.t
    ; page_count : PageCount.t
    }
  [@@deriving eq, show]

  let to_query_parts { limit; page; page_count } =
    [ Common.Message.Field.Limit, Limit.to_string limit
    ; Common.Message.Field.Page, Page.to_string page
    ; Common.Message.Field.PageCount, PageCount.to_string page_count
    ]
  ;;

  let create ?limit ?page ?(page_count = 1) () =
    let open CCOption in
    let open CCFun in
    let build input create default =
      input |> map_or ~default (create %> of_result %> value ~default)
    in
    let page = Page.(build page create default) in
    let limit = value ~default:Limit.default limit in
    { limit; page; page_count }
  ;;

  let set_page_count row_count t =
    let open CCFloat in
    let page_count =
      ceil (of_int row_count /. of_int t.limit) |> to_int |> CCInt.max 1
    in
    { t with page_count }
  ;;

  let to_sql { limit; page; _ } =
    let offset = limit * (page - 1) in
    Format.asprintf "LIMIT %i OFFSET %i " limit offset
  ;;
end

module Search = struct
  module Query = struct
    include Common.Model.String

    let field = Common.Message.Field.Search
    let schema = schema ?validation:None field
    let of_string m = m
  end

  type t =
    { query : Query.t
    ; columns : Column.t list
    }
  [@@deriving eq, show]

  let create query columns = { query; columns }

  let to_sql dyn { columns; query } =
    match columns with
    | [] -> dyn, None
    | columns ->
      let dyn, where =
        columns
        |> CCList.map Column.to_sql
        |> CCList.fold_left
             (fun (dyn, columns) column ->
               ( dyn
                 |> Dynparam.add
                      Caqti_type.string
                      ("%" ^ CCString.(split ~by:" " query |> concat "%") ^ "%")
               , Format.asprintf "%s LIKE ? " column :: columns ))
             (dyn, [])
      in
      where
      |> CCString.concat ") OR ("
      |> Format.asprintf "(%s)"
      |> fun where -> dyn, Some where
  ;;

  let query_string t = t.query |> Query.value
  let to_query_parts t = [ Common.Message.Field.Search, query_string t ]
end

module Sort = struct
  module SortOrder = struct
    include Pool_common.SortOrder

    let to_human lang =
      let open CCFun in
      let open Pool_common in
      (function
        | Ascending -> Message.Ascending
        | Descending -> Message.Descending)
      %> Utils.control_to_string lang
    ;;
  end

  type t =
    { column : Column.t
    ; order : SortOrder.t
    }
  [@@deriving eq, show]

  let create sortable_by ?(order = SortOrder.default) field =
    CCList.find_opt
      CCFun.(fst %> Pool_common.Message.Field.equal field)
      sortable_by
    |> CCOption.map (fun column -> { column; order })
  ;;

  let to_sql { column; order } =
    Format.asprintf "%s %s" (snd column) (SortOrder.show order)
  ;;

  let to_query_parts { column; order } =
    SortOrder.to_query_parts order @ Column.to_query_parts column
  ;;
end

module Filter = struct
  module SelectOption = struct
    type label = (Pool_common.Language.t * string) list [@@deriving eq, show]

    type t =
      { label : label
      ; value : string
      }
    [@@deriving eq, show]

    let create label value = { label; value }

    let label language { label; _ } =
      CCList.assoc ~eq:Pool_common.Language.equal language label
    ;;

    let value { value; _ } = value

    let find_by_value options param =
      CCList.find_opt (fun { value; _ } -> CCString.equal value param) options
    ;;
  end

  module Condition = struct
    module Human = struct
      type t =
        | Checkbox of Column.t
        | Select of Column.t * SelectOption.t list
      [@@deriving eq, show]

      let column = function
        | Checkbox col | Select (col, _) -> col
      ;;
    end

    type t =
      | Checkbox of Column.t * bool
      | Select of Column.t * SelectOption.t
    [@@deriving eq, show, variants]

    let column = function
      | Checkbox (col, _) | Select (col, _) -> col
    ;;
  end

  type human = Condition.Human.t list [@@deriving eq, show]
  type t = Condition.t list [@@deriving eq, show]

  let to_query_parts t =
    let open Condition in
    t
    |> CCList.map (function
      | Checkbox (col, active) ->
        Column.field col, Pool_common.Model.Boolean.stringify active
      | Select (col, option) -> Column.field col, SelectOption.value option)
  ;;

  let to_sql ?where dyn (m : t) =
    m
    |> CCList.fold_left
         (fun default conditon ->
           let dyn, sql = default in
           let open Condition in
           match conditon with
           | Checkbox (col, active) ->
             if active then dyn, sql @ [ Column.to_sql col ] else default
           | Select (col, option) ->
             ( dyn |> Dynparam.add Caqti_type.string (SelectOption.value option)
             , sql @ [ Format.asprintf "%s = ?" (Column.to_sql col) ] ))
         (dyn, [])
    |> fun (dyn, sql) ->
    match sql with
    | [] -> dyn, where
    | sql ->
      let conditions = CCString.concat " AND " sql in
      (match where with
       | None -> dyn, Some conditions
       | Some where -> dyn, Some (Format.asprintf "%s AND %s" where conditions))
  ;;
end

type t =
  { filter : Filter.t option
  ; pagination : Pagination.t option
  ; search : Search.t option
  ; sort : Sort.t option
  }
[@@deriving eq, show]

let to_uri_query ?(additional_params = []) { filter; pagination; search; sort } =
  [ filter |> CCOption.map Filter.to_query_parts
  ; pagination |> Option.map Pagination.to_query_parts
  ; search |> Option.map Search.to_query_parts
  ; sort |> Option.map Sort.to_query_parts
  ]
  |> List.map (Option.value ~default:[])
  |> List.flatten
  |> CCList.append additional_params
  |> List.map (fun (k, v) -> Common.Message.Field.show k, [ Uri.pct_encode v ])
;;

let filter { filter; _ } = filter
let pagination { pagination; _ } = pagination
let search { search; _ } = search
let sort { sort; _ } = sort

let create ?filter ?pagination ?search ?sort () =
  { filter; pagination; search; sort }
;;

let with_sort_order order t =
  let sort = t.sort |> Option.map (fun sort -> Sort.{ sort with order }) in
  { t with sort }
;;

let with_sort_column column t =
  let sort = t.sort |> Option.map (fun sort -> Sort.{ sort with column }) in
  { t with sort }
;;

let set_page_count ({ pagination; _ } as t) row_count =
  let pagination =
    pagination |> CCOption.map (Pagination.set_page_count row_count)
  in
  { t with pagination }
;;

let apply_default ~default t =
  let open CCOption.Infix in
  let filter = t.filter <+> (default >>= filter) in
  let search = t.search <+> (default >>= search) in
  let sort = t.sort <+> (default >>= sort) in
  { t with filter; sort; search }
;;
