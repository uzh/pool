include Repo_entity
module RepoFileMapping = Repo_file_mapping

let to_entity = to_entity
let of_entity = of_entity

module Sql = struct
  let select_sql =
    {sql|
      SELECT
        LOWER(CONCAT(
          SUBSTR(HEX(pool_locations.uuid), 1, 8), '-',
          SUBSTR(HEX(pool_locations.uuid), 9, 4), '-',
          SUBSTR(HEX(pool_locations.uuid), 13, 4), '-',
          SUBSTR(HEX(pool_locations.uuid), 17, 4), '-',
          SUBSTR(HEX(pool_locations.uuid), 21)
        )),
        pool_locations.name,
        pool_locations.description,
        pool_locations.is_virtual,
        pool_locations.institution,
        pool_locations.room,
        pool_locations.building,
        pool_locations.street,
        pool_locations.zip,
        pool_locations.city,
        pool_locations.link,
        pool_locations.status,
        pool_locations.created_at,
        pool_locations.updated_at
      FROM
        pool_locations
    |sql}
  ;;

  let find_request =
    let open Caqti_request.Infix in
    {sql|
      WHERE
        pool_locations.uuid = UNHEX(REPLACE(?, '-', ''))
    |sql}
    |> Format.asprintf "%s\n%s" select_sql
    |> Id.t ->! t
  ;;

  let find pool id =
    let open Utils.Lwt_result.Infix in
    Utils.Database.find_opt (Pool_database.Label.value pool) find_request id
    ||> CCOption.to_result Pool_common.Message.(NotFound Field.Location)
  ;;

  let find_all_request =
    let open Caqti_request.Infix in
    "" |> Format.asprintf "%s\n%s" select_sql |> Caqti_type.unit ->* t
  ;;

  let find_all pool =
    Utils.Database.collect (Pool_database.Label.value pool) find_all_request ()
  ;;

  let insert_request =
    let open Caqti_request.Infix in
    {sql|
      INSERT INTO pool_locations (
        uuid,
        name,
        description,
        is_virtual,
        institution,
        room,
        building,
        street,
        zip,
        city,
        link,
        status,
        created_at,
        updated_at
      ) VALUES (
        UNHEX(REPLACE(?, '-', '')),
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?
      )
    |sql}
    |> t ->. Caqti_type.unit
  ;;

  let insert pool =
    Utils.Database.exec (Pool_database.Label.value pool) insert_request
  ;;

  let update_request =
    let open Caqti_request.Infix in
    {sql|
      UPDATE pool_locations
      SET
        name = $2,
        description = $3,
        is_virtual = $4,
        institution = $5,
        room = $6,
        building = $7,
        street = $8,
        zip = $9,
        city = $10,
        link = $11,
        status = $12
      WHERE
        pool_locations.uuid = UNHEX(REPLACE($1, '-', ''))
    |sql}
    |> Caqti_type.(
         tup2
           Id.t
           (tup2
              Name.t
              (tup2
                 (option Description.t)
                 (tup2 Address.t (tup2 (option Link.t) Status.t))))
         ->. unit)
  ;;

  let update pool { Entity.id; name; description; address; link; status; _ } =
    Utils.Database.exec
      (Pool_database.Label.value pool)
      update_request
      (id, (name, (description, (address, (link, status)))))
  ;;
end

let files_to_location pool ({ id; _ } as location) =
  let open Utils.Lwt_result.Infix in
  RepoFileMapping.find_by_location pool id ||> to_entity location
;;

let find pool id =
  let open Utils.Lwt_result.Infix in
  (* TODO Implement as transaction *)
  Sql.find pool id |>> files_to_location pool
;;

let find_all pool =
  let open Utils.Lwt_result.Infix in
  (* TODO Implement as transaction *)
  Sql.find_all pool >|> Lwt_list.map_s (files_to_location pool)
;;

let insert pool location files =
  let%lwt () = location |> of_entity |> Sql.insert pool in
  files |> Lwt_list.iter_s (RepoFileMapping.insert pool)
;;

let update = Sql.update
