(* camlp4r ./def.syn.cmo ./pa_html.cmo *)
(* $Id: some.ml,v 4.6 2002-01-30 11:49:51 ddr Exp $ *)
(* Copyright (c) 2001 INRIA *)

open Def;
open Gutil;
open Config;
open Util;

value not_found conf txt x =
  let title _ = Wserver.wprint "%s: \"%s\"" (capitale txt) x in
  do {
    rheader conf title; print_link_to_welcome conf False; trailer conf;
  }
;

value first_name_not_found conf =
  not_found conf (transl conf "first name not found")
;

value surname_not_found conf =
  not_found conf (transl conf "surname not found")
;

value persons_of_fsname conf base find proj x =
  let istrl = base.func.strings_of_fsname x in
  let l =
    let x = Name.crush_lower x in
    List.fold_right
      (fun istr l ->
         let str = nominative (sou base istr) in
         if Name.crush_lower str = x ||
            List.mem x (List.map Name.crush_lower (surnames_pieces str)) then
           let iperl = find istr in
           let iperl =
             List.fold_left
               (fun iperl iper ->
                  if proj (pget conf base iper) = istr then [iper :: iperl]
                  else iperl)
               [] iperl
           in
           if iperl = [] then l else [(str, istr, iperl) :: l]
         else l)
      istrl []
  in
  let (l, name_inj) =
    let (l1, name_inj) =
      let x = Name.lower x in
      (List.fold_right
         (fun (str, istr, iperl) l ->
            if x = Name.lower str then [(str, istr, iperl) :: l] else l)
         l [],
       Name.lower)
    in
    let (l1, name_inj) =
      if l1 = [] then
        let x = Name.strip_lower x in
        (List.fold_right
           (fun (str, istr, iperl) l ->
              if x = Name.strip_lower str then [(str, istr, iperl) :: l]
              else l)
           l [],
         Name.strip_lower)
      else (l1, name_inj)
    in
    if l1 = [] then (l, Name.crush_lower) else (l1, name_inj)
  in
  (l, name_inj)
;

value print_elem conf base is_surname (p, xl) =
  list_iter_first
    (fun first x ->
       do {
         if not first then html_li conf else ();
         Wserver.wprint "<a href=\"%s%s\">" (commd conf) (acces conf base x);
         if is_surname then
           Wserver.wprint "%s%s" (surname_end p) (surname_begin p)
         else Wserver.wprint "%s" p;
         Wserver.wprint "</a>";
         Date.afficher_dates_courtes conf base x;
         Wserver.wprint " <em>";
         preciser_homonyme conf base x;
         Wserver.wprint "</em>\n";
       })
    xl
;

value first_name_print_list conf base xl liste =
  let liste =
    let l =
      Sort.list
        (fun x1 x2 ->
           match alphabetique (p_surname base x1) (p_surname base x2) with
           [ 0 ->
               match
                 (Adef.od_of_codate x1.birth, Adef.od_of_codate x2.birth)
               with
               [ (Some d1, Some d2) -> d1 strictement_apres d2
               | (Some d1, _) -> False
               | _ -> True ]
           | n -> n > 0 ])
        liste
    in
    List.fold_left
      (fun l x ->
         let px = p_surname base x in
         match l with
         [ [(p, l1) :: l] when alphabetique px p == 0 -> [(p, [x :: l1]) :: l]
         | _ -> [(px, [x]) :: l] ])
      [] l
  in
  let title _ =
    do {
      Wserver.wprint "%s" (List.hd xl);
      List.iter (fun x -> Wserver.wprint ", %s" x) (List.tl xl);
    }
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    print_alphab_list conf (fun (p, _) -> String.sub p (initiale p) 1)
      (print_elem conf base True) liste;
    trailer conf;
  }
;

value select_first_name conf base n list =
  let title _ =
    Wserver.wprint "%s \"%s\" : %s"
      (capitale (transl_nth conf "first name/first names" 0)) n
      (transl conf "specify")
  in
  do {
    header conf title;
    Wserver.wprint "<ul>";
    List.iter
      (fun (sstr, (strl, _)) ->
         do {
           Wserver.wprint "\n";
           html_li conf;
           Wserver.wprint "<a href=\"%sm=P;v=%s\">" (commd conf)
             (code_varenv sstr);
           Wserver.wprint "%s" (List.hd strl);
           List.iter (fun s -> Wserver.wprint ", %s" s) (List.tl strl);
           Wserver.wprint "</a>\n";
         })
      list;
    Wserver.wprint "</ul>\n";
    trailer conf;
  }
;

value rec merge_insert ((sstr, (strl, iperl)) as x) =
  fun
  [ [((sstr1, (strl1, iperl1)) as y) :: l] ->
      if sstr < sstr1 then [x; y :: l]
      else if sstr > sstr1 then [y :: merge_insert x l]
      else [(sstr, (strl @ strl1, iperl @ iperl1)) :: l]
  | [] -> [x] ]
;

value first_name_print conf base x =
  let (list, _) =
    if x = "" then ([], fun [])
    else
      persons_of_fsname conf base base.func.persons_of_first_name.find
        (fun x -> x.first_name) x
  in
  let list =
    List.map (fun (str, istr, iperl) -> (Name.lower str, ([str], iperl))) list
  in
  let list = List.fold_right merge_insert list [] in
  match list with
  [ [] -> first_name_not_found conf x
  | [(_, (strl, iperl))] ->
      let pl = List.map (pget conf base) iperl in
      let pl =
        if conf.hide_names then
          List.fold_right
            (fun p pl -> if fast_auth_age conf p then [p :: pl] else pl)
            pl []
        else pl
      in
      first_name_print_list conf base strl pl
  | _ -> select_first_name conf base x list ]
;

value she_has_children_with_her_name conf base wife husband children =
  let wife_surname = Name.strip_lower (p_surname base wife) in
  if Name.strip_lower (p_surname base husband) = wife_surname then False
  else
    List.exists
      (fun c ->
         Name.strip_lower (p_surname base (pget conf base c)) = wife_surname)
      (Array.to_list children)
;

value afficher_date_mariage conf base fam p c =
  Wserver.wprint "%s" (Date.short_marriage_date_text conf base fam p c)
;

value max_lev = 3;

value rec print_branch conf base first_lev psn lev name p =
  do {
    if lev == 0 then () else html_li conf;
    Wserver.wprint "<strong>";
    Wserver.wprint "%s"
      (Util.reference conf base p
         (if conf.hide_names && not (fast_auth_age conf p) then "x"
          else if not psn && p_surname base p = name then
            person_text_without_surname conf base p
          else person_text conf base p));
    Wserver.wprint "</strong>";
    Date.afficher_dates_courtes conf base p;
    Wserver.wprint "\n";
    let u = uget conf base p.cle_index in
    if Array.length u.family == 0 then ()
    else
      let _ =
        List.fold_left
          (fun (first, need_br) ifam ->
             let fam = foi base ifam in
             let des = doi base ifam in
             let c = spouse p.cle_index (coi base ifam) in
             let el = des.children in
             let c = pget conf base c in
             do {
               if need_br then html_br conf else ();
               if not first then do {
                 Wserver.wprint "<em>";
                 Wserver.wprint "%s"
                   (if conf.hide_names && not (fast_auth_age conf p) then "x"
                    else if p_surname base p = name then
                      person_text_without_surname conf base p
                    else person_text conf base p);
                 Wserver.wprint "</em>";
                 Date.afficher_dates_courtes conf base p;
                 Wserver.wprint "\n";
               }
               else ();
               Wserver.wprint "  &amp;";
               afficher_date_mariage conf base fam p c;
               Wserver.wprint " <strong>";
               Wserver.wprint "%s"
                 (reference conf base c
                    (if conf.hide_names && not (fast_auth_age conf c) then "x"
                     else person_text conf base c));
               Wserver.wprint "</strong>";
               Date.afficher_dates_courtes conf base c;
               Wserver.wprint "\n";
               let down =
                 p.sex = Male &&
                 (Name.crush_lower (p_surname base p) =
                    Name.crush_lower name ||
                  first_lev) &&
                 Array.length el <> 0 ||
                 p.sex = Female &&
                 she_has_children_with_her_name conf base p c el
               in
               if down then do {
                 Wserver.wprint "<ul>\n";
                 List.iter
                   (fun e ->
                      print_branch conf base False psn (succ lev) name
                        (pget conf base e))
                   (Array.to_list el);
                 Wserver.wprint "</ul>\n";
                 (False, not down)
               }
               else (False, not down)
             })
          (True, False) (Array.to_list u.family)
      in
      ()
  }
;

value print_by_branch x conf base not_found_fun (pl, homonymes) =
  let ancestors =
    Sort.list
      (fun p1 p2 ->
         alphabetique (p_first_name base p1) (p_first_name base p2) <= 0)
      pl
  in
  let len = List.length ancestors in
  if len == 0 then not_found_fun conf x
  else do {
    let fx = x in
    let x =
      match homonymes with
      [ [x :: _] -> x
      | _ -> x ]
    in
    let psn =
      match homonymes with
      [ [_] ->
          try List.assoc "always_surname" conf.base_env = "yes" with
          [ Not_found -> False ]
      | _ -> True ]
    in
    let title h =
      let access x =
        if h || List.length homonymes = 1 then x
        else geneweb_link conf ("m=N;v=" ^ code_varenv (Name.lower x)) x
      in
      do {
        Wserver.wprint "%s" (access (List.hd homonymes));
        List.iter (fun x -> Wserver.wprint ", %s" (access x))
          (List.tl homonymes);
      }
    in
    let br = p_getint conf.env "br" in
    header conf title;
    print_link_to_welcome conf True;
    if br = None then do {
      Wserver.wprint "<font size=-1><em>\n";
      Wserver.wprint "%s " (capitale (transl conf "click"));
      Wserver.wprint "<a href=\"%sm=N;o=i;v=%s\">%s</a>\n" (commd conf)
        (code_varenv fx) (transl conf "here");
      Wserver.wprint "%s"
        (transl conf "for the first names by alphabetic order");
      Wserver.wprint ".</em></font>\n";
      html_p conf;
    }
    else ();
(*
    Wserver.wprint "<nobr>\n";
*)
    if len > 1 && br = None then do {
      Wserver.wprint "%s: %d" (capitale (transl conf "number of branches"))
        len;
      html_p conf;
      Wserver.wprint "<dl>\n";
    }
    else ();
    let _ =
      List.fold_left
        (fun n p ->
           do {
             if len > 1 && br = None then do {
               Wserver.wprint "<dt>";
               stag "a" "href=\"%sm=N;v=%s;br=%d\"" (commd conf)
                   (Util.code_varenv fx) n begin
                 Wserver.wprint "%d." n;
               end;
               Wserver.wprint "\n<dd>\n";
             }
             else ();
             if br = None || br = Some n then
               match (aget conf base p.cle_index).parents with
               [ Some ifam ->
                   let cpl = coi base ifam in
                   do {
                     let href =
                       Util.acces conf base (pget conf base cpl.father)
                     in
                     wprint_geneweb_link conf href "&lt;&lt";
                     Wserver.wprint "\n&amp;\n";
                     let href =
                       Util.acces conf base (pget conf base cpl.mother)
                     in
                     wprint_geneweb_link conf href "&lt;&lt";
                     Wserver.wprint "\n";
                     tag "ul" begin
                       print_branch conf base True psn 1 x p;
                     end;
                   }
               | None -> print_branch conf base True psn 0 x p ]
             else ();
             n + 1
           })
        1 ancestors
    in
    if len > 1 && br = None then Wserver.wprint "</dl>\n" else ();
(*
    Wserver.wprint "</nobr>\n";
*)
    trailer conf;
  }
;

value print_family_alphabetic x conf base liste =
  let homonymes =
    let list =
      List.fold_left
        (fun list p ->
           if List.memq p.surname list then list else [p.surname :: list])
        [] liste
    in
    let list = List.map (fun s -> sou base s) list in List.sort compare list
  in
  let liste =
    let l =
      Sort.list
        (fun x1 x2 ->
           match
             alphabetique (p_first_name base x1) (p_first_name base x2)
           with
           [ 0 -> x1.occ > x2.occ
           | n -> n > 0 ])
        liste
    in
    List.fold_left
      (fun l x ->
         let px = p_first_name base x in
         match l with
         [ [(p, l1) :: l] when alphabetique px p == 0 -> [(p, [x :: l1]) :: l]
         | _ -> [(px, [x]) :: l] ])
      [] l
  in
  match liste with
  [ [] -> surname_not_found conf x
  | _ ->
      let title h =
        let access x =
          if h || List.length homonymes = 1 then x
          else geneweb_link conf ("m=N;o=i;v=" ^ code_varenv (Name.lower x)) x
        in
        do {
          Wserver.wprint "%s" (access (List.hd homonymes));
          List.iter (fun x -> Wserver.wprint ", %s" (access x))
            (List.tl homonymes);
        }
      in
      do {
        header conf title;
        print_link_to_welcome conf True;
        print_alphab_list conf (fun (p, _) -> String.sub p (initiale p) 1)
          (print_elem conf base False) liste;
        trailer conf;
      } ]
;

value has_at_least_2_children_with_surname conf base des surname =
  loop 0 0 where rec loop cnt i =
    if i == Array.length des.children then False
    else
      let p = pget conf base des.children.(i) in
      if p.surname == surname then
        if cnt == 1 then True else loop (cnt + 1) (i + 1)
      else loop cnt (i + 1)
;

value select_ancestors conf base name_inj ipl =
  let str_inj s = name_inj (sou base s) in
  List.fold_left
    (fun ipl ip ->
       let p = pget conf base ip in
       let a = aget conf base ip in
       match a.parents with
       [ Some ifam ->
           let cpl = coi base ifam in
           let fath = pget conf base cpl.father in
           let moth = pget conf base cpl.mother in
           let s = str_inj p.surname in
           if str_inj fath.surname <> s && str_inj moth.surname <> s &&
              not (List.memq ip ipl) then
             if List.memq cpl.father ipl then ipl
             else if not (is_hidden fath) &&
               has_at_least_2_children_with_surname conf base (doi base ifam)
                 p.surname then
               [cpl.father :: ipl]
             else [ip :: ipl]
           else ipl
       | _ -> [ip :: ipl] ])
    [] ipl
;

value surname_print conf base not_found_fun x =
  let (l, name_inj) =
    if x = "" then ([], fun [])
    else
      persons_of_fsname conf base base.func.persons_of_surname.find
        (fun x -> x.surname) x
  in
  let (iperl, strl) =
    List.fold_right
      (fun (str, istr, iperl1) (iperl, strl) ->
         let len = List.length iperl1 in
         (iperl1 @ iperl, [(str, len) :: strl]))
      l ([], [])
  in
  let strl = Sort.list (fun (_, len1) (_, len2) -> len1 >= len2) strl in
  let strl = List.map fst strl in
  match p_getenv conf.env "o" with
  [ Some "i" ->
      let pl =
        List.fold_right (fun ip ipl -> [pget conf base ip :: ipl]) iperl []
      in
      let pl =
        if conf.hide_names then
          List.fold_right
            (fun p pl -> if Util.fast_auth_age conf p then [p :: pl] else pl)
            pl []
        else pl
      in
      print_family_alphabetic x conf base pl
  | _ ->
      let iperl = select_ancestors conf base name_inj iperl in
      let pl = List.map (pget conf base) iperl in
      print_by_branch x conf base not_found_fun (pl, strl) ]
;
