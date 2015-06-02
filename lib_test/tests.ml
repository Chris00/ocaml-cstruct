open OUnit

let _ = Random.self_init ()

let random_cs ?(len = Random.int 128) () =
  let cs = Cstruct.create len in
  for i = 0 to len - 1 do Cstruct.set_uint8 cs i (Random.int 256) done;
  cs

let to_string_as_sexp cs =
  Sexplib.Sexp.to_string_mach (Cstruct.sexp_of_t cs)

let of_string_as_sexp str =
  Cstruct.t_of_sexp (Sexplib.Sexp.of_string str)

let assert_cs_equal ?msg cs1 cs2 =
  assert_equal ~cmp:Cstruct.equal ~printer:Cstruct.to_string ?msg cs1 cs2

let assert_string_equal ?msg s1 s2 =
  assert_equal ~printer:(fun s -> s) ?msg s1 s2

let sexp_repr =
  let open Cstruct in
  let cs1 = of_string "abcdefgh" in
  let cs2 = shift cs1 2
  and cs3 = sub cs1 2 4 in
  let cs4 = of_string "a b\nc" in
  let cs5 = sub cs4 2 1 in
  [ (cs1, "abcdefgh")
  ; (cs2, "cdefgh")
  ; (cs3, "cdef")
  ; (cs4, "\"a b\\nc\"")
  ; (cs5, "b")
  ]

let sexp_writer () =
  sexp_repr |> List.iter @@ fun (cs, str) ->
    assert_string_equal str (to_string_as_sexp cs)

let sexp_reader () =
  sexp_repr |> List.iter @@ fun (cs, str) ->
    assert_cs_equal cs (of_string_as_sexp str)

let sexp_invertibility ~n () =
  for i = 1 to n do
    let cs1 = random_cs () in
    let s1  = to_string_as_sexp cs1 in
    let cs2 = of_string_as_sexp s1  in
    let s2  = to_string_as_sexp cs2 in
    assert_cs_equal     ~msg:"recovered cstruct" cs1 cs2 ;
    assert_string_equal ~msg:"recovered string"  s1  s2
  done

let concat_ex =
  let open Cstruct in
  List.map (fun (ss, s) -> (List.map of_string ss, of_string s))
  [ ([], "")
  ; (["abcd"], "abcd")
  ; ([""], "")
  ; ([""; ""], "")
  ; ([""; "ab"; ""; "cd"], "abcd")
  ; (["ab"; "cd"; "ef"], "abcdef")
  ]

let concat_samples () =
  concat_ex |> List.iter @@ fun (css, cs) ->
    assert_cs_equal cs (Cstruct.concat css)

let concat_random ~n () =
  let rec explode cs =
    let n = Cstruct.len cs in
    if n = 0 then [] else
      let k = Random.int (n + 1) in
      Cstruct.sub cs 0 k :: explode (Cstruct.shift cs k) in
  for i = 1 to n do
    let cs  = random_cs () in
    let css = explode cs in
    assert_cs_equal cs (Cstruct.concat css)
  done

let append_is_concat ~n () =
  for i = 1 to n do
    let (cs1, cs2) = (random_cs (), random_cs ()) in
    assert_cs_equal (Cstruct.concat [cs1; cs2]) (Cstruct.append cs1 cs2)
  done

let _ =
  let suite =
    "misc tests" >::: [
      "sexp" >::: [
        "sexp_of_t" >:: sexp_writer
      ; "t_of_sexp" >:: sexp_reader
      ; "sexp invertibility" >:: sexp_invertibility ~n:5000
      ] ;
      "concat" >::: [
        "concat samples" >:: concat_samples
      ; "concat random"  >:: concat_random ~n:5000
      ] ;
      "append" >::: [
        "append is concat" >:: append_is_concat ~n:5000
      ]
    ]
  in
  run_test_tt suite

