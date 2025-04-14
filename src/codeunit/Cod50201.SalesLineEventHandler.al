codeunit 50201 "SalesLineEventHandler"
{
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterQuantityValidate(var Rec: Record "Sales Line")
    var
        AvailableQty: Integer;
        RequestedQty: Integer;
    begin
        RequestedQty := Rec.Quantity;
        AvailableQty := GetAvailableQuantity(Rec."No.", Rec."Location Code");

        if RequestedQty > AvailableQty then
            HandleInsufficientStock(Rec, RequestedQty, AvailableQty);
    end;

    local procedure GetAvailableQuantity(ItemNo: Code[20]; LocationCode: Code[10]): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange("Location Code", LocationCode);
        if ItemLedgerEntry.CalcSums("Remaining Quantity") then
            exit(ItemLedgerEntry."Remaining Quantity")
        else
            exit(0);
    end;

    local procedure HandleInsufficientStock(SalesLine: Record "Sales Line"; RequestedQty: Integer; AvailableQty: Integer)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalPost: Codeunit "Item Jnl.-Post";
        RemainingQty: Integer;
        NextLineNo: Integer;
    begin
        RemainingQty := RequestedQty - AvailableQty;

        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Journal Template Name", 'ITEM');
        ItemJournalLine.SetRange("Journal Batch Name", 'DEFAULT');

        if ItemJournalLine.FindLast() then
            NextLineNo := ItemJournalLine."Line No." + 10000
        else
            NextLineNo := 10000;

        ItemJournalLine.Init();
        ItemJournalLine.Validate("Journal Template Name", 'ITEM');
        ItemJournalLine.Validate("Journal Batch Name", 'DEFAULT');
        ItemJournalLine.Validate("Line No.", NextLineNo);
        ItemJournalLine.Validate("Item No.", SalesLine."No.");
        ItemJournalLine."Location Code" := SalesLine."Location Code";
        ItemJournalLine.Validate("Quantity", RemainingQty);
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Positive Adjmt.");
        ItemJournalLine.Validate("Posting Date", Today);
        ItemJournalLine.Validate("Document No.", 'ADJ-' + Format(Today, 0, '<Day,2>/<Month,2>/<Year4>'));

        ItemJournalLine.Insert(true);


        ItemJournalPost.Run(ItemJournalLine);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', false, false)]
    local procedure OnBeforeCode(var ItemJournalLine: Record "Item Journal Line"; var HideDialog: Boolean; var SuppressCommit: Boolean;
    var IsHandled: Boolean)
    begin

        HideDialog := true;
    end;
}
