Require Import Lts.Syntax Lts.Notations.
Require Import Ex.Msi.

Definition MemOp := Bool.

Definition toMsi var (x: (MemOp @ var)%kami): (Msi @ var)%kami :=
  (IF x then $ Mod else $ Sh)%kami_expr.

Section MsgTypes.
  Variables LgDataBytes LgNumDatas LgNumChildren: nat.
  Variable Addr Id: Kind.
  Definition Child := Bit LgNumChildren.
  Definition Data := Bit (LgDataBytes * 8).
  Definition Line := Vector Data LgNumDatas.

  Definition RqFromProc := STRUCT {
                               "addr" :: Addr;
                               "op" :: MemOp;
                               (* "byteEn" :: Vector Bool LgDataBytes; *)
                               "data" :: Data
                               (* "id" :: Id *)
                             }.

  Definition RsToProc := STRUCT {
                             "data" :: Data
                             (* "id" :: Id *)
                           }.

  Definition FromP := STRUCT {
                          "isRq" :: Bool;
                          "addr" :: Addr;
                          "to" :: Msi;
                          "line" :: Line;
                          "id" :: Id
                        }.

  Definition RqFromP := STRUCT {
                            "addr" :: Addr;
                            "to" :: Msi
                          }.

  Definition RsFromP := STRUCT {
                            "addr" :: Addr;
                            "to" :: Msi;
                            "line" :: Line;
                            "id" :: Id
                          }.

  Definition RqToP := STRUCT {
                          "addr" :: Addr;
                          "from" :: Msi;
                          "to" :: Msi;
                          "id" :: Id
                        }.

  Definition RsToP := STRUCT {
                          "addr" :: Addr;
                          "to" :: Msi;
                          "line" :: Line
                        }.

  Definition RqFromC := STRUCT {
                            "child" :: Child;
                            "rq" :: RqToP
                          }.

  Definition RsFromC := STRUCT {
                            "child" :: Child;
                            "rs" :: RsToP
                          }.

  Definition ToC := STRUCT {
                        "child" :: Child;
                        "msg" :: FromP
                      }.
End MsgTypes.

Definition RqState := Bit 3.
Definition Empty := 0.
Definition Init := 1.
Definition WaitOldTag := 2.
Definition WaitNewTag := 3.
Definition WaitSt := 4.
Definition Processing := 5.
Definition Depend := 6.
Definition Done := 7.

Hint Unfold MemOp toMsi Child Data Line : MethDefs.
Hint Unfold RqFromProc RsToProc FromP RqFromP RsFromP RqToP
     RsToP RqFromC RsFromC ToC : MethDefs.
Hint Unfold RqState Empty Init WaitOldTag WaitNewTag WaitSt
     Processing Depend Done : MethDefs.

