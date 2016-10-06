Require Import Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word.
Require Import Lib.Struct Lib.StructNotation Lib.StringBound Lib.FMap Lib.StringEq Lib.Indexer.
Require Import Kami.Syntax Kami.Semantics Kami.RefinementFacts Kami.Renaming Kami.Wf.
Require Import Kami.Renaming Kami.Inline Kami.InlineFacts.
Require Import Kami.Decomposition Kami.Notations Kami.Tactics.
Require Import Ex.MemTypes Ex.NativeFifo Ex.MemAtomic.
Require Import Ex.SC Ex.ProcDec Ex.ProcTwoStage Ex.ProcTwoStInl Ex.ProcTwoStInv.
Require Import Eqdep.

Set Implicit Arguments.

Section ProcTwoStDec.
  Variables addrSize lgDataBytes rfIdx: nat.

  (* External abstract ISA: decoding and execution *)
  Variables (getOptype: OptypeT lgDataBytes)
            (getLdDst: LdDstT lgDataBytes rfIdx)
            (getLdAddr: LdAddrT addrSize lgDataBytes)
            (getLdSrc: LdSrcT lgDataBytes rfIdx)
            (calcLdAddr: LdAddrCalcT addrSize lgDataBytes)
            (getStAddr: StAddrT addrSize lgDataBytes)
            (getStSrc: StSrcT lgDataBytes rfIdx)
            (calcStAddr: StAddrCalcT addrSize lgDataBytes)
            (getStVSrc: StVSrcT lgDataBytes rfIdx)
            (getSrc1: Src1T lgDataBytes rfIdx)
            (getSrc2: Src2T lgDataBytes rfIdx)
            (execState: ExecStateT addrSize lgDataBytes rfIdx)
            (execNextPc: ExecNextPcT addrSize lgDataBytes rfIdx)
            (predictNextPc: forall ty, fullType ty (SyntaxKind (Bit addrSize)) -> (* pc *)
                                       Expr ty (SyntaxKind (Bit addrSize))).

  Definition RqFromProc := MemTypes.RqFromProc lgDataBytes (Bit addrSize).
  Definition RsToProc := MemTypes.RsToProc lgDataBytes.

  Definition p2st := ProcTwoStage.p2st
                       getOptype getLdDst getLdAddr getLdSrc calcLdAddr
                       getStAddr getStSrc calcStAddr getStVSrc
                       getSrc1 execState execNextPc predictNextPc.
  Definition pdec := ProcDec.pdec
                       getOptype getLdDst getLdAddr getLdSrc calcLdAddr
                       getStAddr getStSrc calcStAddr getStVSrc
                       getSrc1 execState execNextPc.

  Hint Unfold p2st: ModuleDefs. (* for kinline_compute *)
  Hint Extern 1 (ModEquiv type typeUT p2st) => unfold p2st. (* for kequiv *)
  Hint Extern 1 (ModEquiv type typeUT pdec) => unfold pdec. (* for kequiv *)

  Definition p2st_pdec_ruleMap (o: RegsT): string -> option string :=
    "reqLd" |-> "reqLd";
      "reqLdZ" |-> "reqLdZ";
      "reqSt" |-> "reqSt";
      "repLd" |-> "repLd";
      "repSt" |-> "repSt";
      "execToHost" |-> "execToHost";
      "execNm" |-> "execNm"; ||.
  Hint Unfold p2st_pdec_ruleMap: MethDefs.

  Definition p2st_pdec_regMap (r: RegsT): RegsT :=
    (mlet pcv : (Bit addrSize) <- r |> "pc";
       mlet pgmv : (Vector (Data lgDataBytes) addrSize) <- r |> "pgm";
       mlet rfv : (Vector (Data lgDataBytes) rfIdx) <- r |> "rf";
       mlet d2eeltv : d2eElt addrSize lgDataBytes rfIdx <- r |> "d2e"--"elt";
       mlet d2efv : Bool <- r |> "d2e"--"full";
       mlet e2deltv : Bit addrSize <- r |> "e2d"--"elt";
       mlet e2dfv : Bool <- r |> "e2d"--"full";
       mlet eev : Bool <- r |> "eEpoch";
       mlet stallv : Bool <- r |> "stall";
       mlet stalledv : d2eElt addrSize lgDataBytes rfIdx <- r |> "stalled";

       (["stall" <- existT _ _ stallv]
        +["pgm" <- existT _ _ pgmv]
        +["rf" <- existT _ _ rfv]
        +["pc" <- existT _ (SyntaxKind (Bit addrSize))
               (if stallv then stalledv ``"curPc"
                else if e2dfv then e2deltv
                     else if d2efv then
                            if eqb eev (d2eeltv ``"epoch")
                            then d2eeltv ``"curPc"
                            else pcv
                          else pcv)])%fmap)%mapping.
  Hint Unfold p2st_pdec_regMap: MapDefs.

  Ltac is_not_ife t :=
    match t with
    | context [if _ then _ else _] => fail 1
    | _ => idtac
    end.
  
  Ltac dest_if :=
    match goal with
    | [ |- context[if ?x then _ else _] ] =>
      let c := fresh "c" in is_not_ife x; remember x as c; destruct c
    | [H: context[if ?x then _ else _] |- _] =>
      let c := fresh "c" in is_not_ife x; remember x as c; destruct c
    end.

  Ltac kinv_bool :=
    repeat
      (try match goal with
           | [H: ?t = true |- _] => rewrite H in *
           | [H: ?t = false |- _] => rewrite H in *
           | [H: true = ?t |- _] => rewrite <-H in *
           | [H: false = ?t |- _] => rewrite <-H in *
           end; dest_if; kinv_simpl; intuition idtac).

  Ltac p2st_inv_tac :=
    repeat match goal with
           | [H: p2st_pc_epochs_inv _ _ _ _ |- _] => destruct H
           | [H: p2st_decode_inv _ _ _ _ _ _ _ _ _ _ _ |- _] => destruct H
           | [H: p2st_stalled_inv _ _ _ _ _ _ _ _ _ _ _ |- _] => destruct H
           | [H: p2st_raw_inv _ _ _ _ _ _ |- _] => destruct H
           | [H: p2st_scoreboard_inv _ _ _ _ |- _] => destruct H
           end;
    kinv_red.

  Definition p2stInl := ProcTwoStInl.p2stInl getOptype getLdDst getLdAddr getLdSrc calcLdAddr
                                             getStAddr getStSrc calcStAddr getStVSrc
                                             getSrc1 execState execNextPc predictNextPc.

  Ltac kregmap_red ::=
       repeat autounfold with MethDefs in *;
  repeat autounfold with MapDefs in *;
  kstring_simpl; dest;
  repeat match goal with
         | [H: M.find _ _ = None |- _] => clear H
         end;
  repeat
    (try match goal with
         | [H: M.find ?k ?m = _ |- context[M.find ?k ?m] ] => rewrite H
         | [H1: M.find ?k ?m = _, H2: context[M.find ?k ?m] |- _] => rewrite H1 in H2
         | [ |- context[decKind _ _] ] =>
           rewrite kind_eq; unfold eq_rect_r, eq_rect, eq_sym
         | [H: context[decKind _ _] |- _] =>
           rewrite kind_eq in H; unfold eq_rect_r, eq_rect, eq_sym in H
         end; try subst; try findReify).

  Theorem p2st_refines_pdec:
    p2st <<== pdec.
  Proof. (* SKIP_PROOF_ON
    (* instead of: kinline_left im. *)
    ketrans; [exact (projT2 p2stInl)|].
    kdecompose_nodefs p2st_pdec_regMap p2st_pdec_ruleMap.

    kinv_add p2st_inv_ok.
    kinv_add_end.

    kinvert.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.
    - kinv_action_dest;
        kinv_custom p2st_inv_tac;
        kinv_regmap_red;
        kinv_constr; kinv_eq; kinv_finish_with kinv_bool.

      END_SKIP_PROOF_ON *) admit.

  Qed.

End ProcTwoStDec.
