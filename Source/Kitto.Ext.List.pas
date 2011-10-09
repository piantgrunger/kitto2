unit Kitto.Ext.List;

interface

uses
  Ext, ExtGrid, ExtData, ExtForm,
  EF.ObserverIntf, EF.Classes,
  Kitto.Ext.Base, Kitto.Ext.DataPanel, Kitto.Types, Kitto.Controller,
  Kitto.Metadata.Views, Kitto.Store;

type
  TKExtFilterPanel = class(TExtFormFormPanel)
  private
    FConnector: string;
  public
    property Connector: string read FConnector write FConnector;
    function GetFilterExpression: string;
  end;

  TKExtListPanel = class(TKExtDataPanel)
  private
    FGridPanel: TExtGridEditorGridPanel;
    FPageRecordCount: Integer;
    FIsAddAllowed: Boolean;
    FIsEditAllowed: Boolean;
    FIsDeleteAllowed: Boolean;
    FStore: TExtDataStore;
    FReader: TExtDataJsonReader;
    FGridView: TExtGridGridView;
    FEditHostWindow: TKExtModalWindow;
    FFormController: IKController;
    FPagingToolbar: TExtPagingToolbar;
    FTopToolbar: TExtToolbar;
    FFilterPanel: TKExtFilterPanel;
    procedure InitFieldsAndColumns;
    // Opens an edit window on the specified record.
    procedure ShowEditWindow(const ARecord: TKRecord; const AEditMode: TKEditMode);
    function LocateRecordFromSession: TKRecord;
    procedure RefreshData;
    function CreatePagingToolbar: TExtPagingToolbar;
    procedure EditOrViewCurrentRecord;
    procedure WriteChanges;
    function CreateTopToolbar: TExtToolbar;
    procedure CreateFilterPanel;
    procedure CreateStoreAndView;
    function GetRefreshJSCode: string;
    function GetGroupingFieldName: string;
  protected
    procedure LoadData; override;
    procedure InitComponents; override;
    function GetFilterExpression: string; override;
  public
    destructor Destroy; override;
    procedure UpdateObserver(const ASubject: IEFSubject;
      const AContext: string = ''); override;
  published
    procedure GetRecordPage;
    procedure RowDblClick;
    //procedure EditWindowClosed;
    procedure NewRecord(This: TExtButton; E: TExtEventObjectSingleton);
    procedure DeleteCurrentRecord;
  end;

implementation

uses
  SysUtils, Math, StrUtils, Variants, Types,
  ExtPascal,
  EF.Intf, EF.Localization, EF.StrUtils, EF.Tree, EF.SQL,
  Kitto.Environment, Kitto.AccessControl, Kitto.Ext.Session, Kitto.Ext.Utils,
  Kitto.JSON, Kitto.Ext.Filters, Kitto.SQL;

const
  DEFAULT_PAGE_RECORD_COUNT = 100;
  { TODO : should we just fetch everything when grouping is enabled? }
  DEFAULT_GROUPING_PAGE_RECORD_COUNT = 1000;

{ TKExtListPanel }

procedure TKExtListPanel.DeleteCurrentRecord;
begin
  Assert(ViewTable <> nil);

{ TODO : implement delete/write }
  //LocateRecordFromSession;
  //DataSet.Delete;
  if not ViewTable.IsDetail then
    WriteChanges;
  RefreshData;
end;

procedure TKExtListPanel.WriteChanges;
begin
  Environment.MainDBConnection.StartTransaction;
  try
    { TODO : implement write }
    //FStore.WriteChanges;
    Environment.MainDBConnection.CommitTransaction;
  except
    Environment.MainDBConnection.RollbackTransaction;
    raise;
  end;
end;

destructor TKExtListPanel.Destroy;
begin
  FreeAndNilEFIntf(FFormController);
  FreeAndNil(FEditHostWindow);
  inherited;
end;

//procedure TKExtListPanel.EditWindowClosed;
//begin
//  FreeAndNil(FEditHostWindow);
//end;

procedure TKExtListPanel.GetRecordPage;

  function BuildCommandText(const AAdditionalFilter: string): string;
  var
    LQueryBuilder: TKSQLQueryBuilder;
  begin
    Assert(ViewTable <> nil);

    LQueryBuilder := TKSQLQueryBuilder.Create;
    try
      Result := LQueryBuilder.GetSelectStatement(ViewTable);
      if AAdditionalFilter <> '' then
        Result := AddToSQLWhereClause(Result, AAdditionalFilter);
{ TODO : implement keyset and parameterized queries when needed. }
//      if Assigned(AKeySet) then
//      begin
//        Result := AddToSQLWhereClause(Result, KeySetToSQL(AKeySet));
//        CopyKeySetValuesToParams(AKeySet, DBQuery.Params);
//      end;
    finally
      FreeAndNil(LQueryBuilder);
    end;
  end;

var
  LPageRecordCount: Integer;
  LStart: Integer;
  LLimit: Integer;
  LRecords: string;
begin
  Assert(Assigned(FGridPanel));
  Assert(FGridPanel.Columns.Count > 0);

{ TODO : Fully refreshing at each page change might be inefficient.
  Shall we provide a switch to turn it off on a form-by-form basis, or use
  FIRST/SKIP/ROWS to only fetch relevant rows in a database-dependent way?
  For now, let's just stick with full refresh always. }
  ServerStore.Load(Environment.MainDBConnection,
    BuildCommandText(FFilterPanel.GetFilterExpression));

  LStart := Session.QueryAsInteger['start'];
  LLimit := Session.QueryAsInteger['limit'];
  LPageRecordCount := Min(Max(LLimit, DEFAULT_PAGE_RECORD_COUNT), ServerStore.RecordCount - LStart);

  LRecords := ServerStore.GetAsJSON(LStart, LPageRecordCount);

  { TODO : not sure about the usefulness of this replace here }
  LRecords := AnsiReplaceStr(LRecords, #13#10, '<br/>');
  LRecords := AnsiReplaceStr(LRecords, #10, '<br/>');
  LRecords := AnsiReplaceStr(LRecords, #13, '<br/>');

  Session.Response := '{Total:' + IntToStr(ServerStore.RecordCount) + ',Root:' + LRecords + '}';
end;

function TKExtListPanel.CreatePagingToolbar: TExtPagingToolbar;
begin
  Assert(ViewTable <> nil);

  FPagingToolbar := TExtPagingToolbar.Create;
  FPagingToolbar.Store := FGridPanel.Store;
  FPagingToolbar.DisplayInfo := False;
  FPagingToolbar.PageSize := FPageRecordCount;
  Result := FPagingToolbar;
end;

function TKExtListPanel.GetFilterExpression: string;
begin
  Result := FFilterPanel.GetFilterExpression;
end;

procedure TKExtListPanel.CreateFilterPanel;
var
  LItems: TEFNode;
  I: Integer;
begin
  LItems := ViewTable.GetNode('Controller/Filters/Items');
  if LItems.ChildCount > 0 then
  begin
    FFilterPanel := TKExtFilterPanel.AddTo(Items);
    FFilterPanel.Region := rgNorth;
    FFilterPanel.Title := _(ViewTable.GetString('Controller/Filters/DisplayLabel', 'Filters'));
    FFilterPanel.Collapsible := True;
    FFilterPanel.Frame := True;
    FFilterPanel.Connector := ViewTable.GetString('Controller/Filters/Connector', 'and');
    FFilterPanel.Border := False;
    FFilterPanel.AutoHeight := True;
    for I := 0 to LItems.ChildCount - 1 do
    begin
      // Currently unused.
      LItems.Children[I].SetString('Sys/ApplyJSCode', GetRefreshJSCode);
      TKExtFilterFactory.Instance.CreateFilter(LItems.Children[I], Self, FFilterPanel.Items);
    end;
  end;
end;

function TKExtListPanel.CreateTopToolbar: TExtToolbar;
var
  LNewButton: TExtButton;
  LDeleteButton: TExtButton;
  LKeyFieldNames: string;
begin
  Assert(ViewTable <> nil);

  Result := TExtToolbar.Create;
  // Add buttons.
  if not ViewTable.IsReadOnly then
  begin
    LNewButton := TExtButton.AddTo(Result.Items);
    begin
      LNewButton.Text := 'New Record';
      LNewButton.Icon := Environment.GetImageURL('new_record_16.png');
      LNewButton.Disabled := not FIsAddAllowed;
      if not LNewButton.Disabled then
        LNewButton.OnClick := NewRecord;
    end;
    TExtToolbarSpacer.AddTo(Result.Items);
    LDeleteButton := TExtButton.AddTo(Result.Items);
    begin
      LDeleteButton.Text := 'Delete Record';
      LDeleteButton.Icon := Environment.GetImageURL('delete_record_16.png');
      LDeleteButton.Disabled := not FIsDeleteAllowed;
      if not LDeleteButton.Disabled then
      begin
        LKeyFieldNames := Join(ViewTable.GetKeyFieldAliasedNames, ',');
        LDeleteButton.On('click', AjaxSelection(DeleteCurrentRecord,
          TExtGridRowSelectionModel(FGridPanel.SelModel), LKeyFieldNames, LKeyFieldNames, []));
      end;
    end;
  end;
end;

function TKExtListPanel.GetGroupingFieldName: string;
begin
  Result := ViewTable.GetString('Controller/Grouping/FieldName');
end;

procedure TKExtListPanel.InitComponents;
var
  LSelModel: TExtGridRowSelectionModel;
  LKeyFieldNames: string;
begin
  inherited;
  Title := ViewTable.PluralDisplayLabel;

  { TODO : implement resource URIs }
  FIsAddAllowed := not ViewTable.GetBoolean('Controller/PreventAdding', False);
    //and Environment.IsAccessGranted(GUIForm.GetResourceURI, ACM_ADD);
  FIsEditAllowed := not ViewTable.GetBoolean('Controller/PreventEditing', False);
    //and Environment.IsAccessGranted(GUIForm.GetResourceURI, ACM_MODIFY);
  FIsDeleteAllowed := not ViewTable.GetBoolean('Controller/PreventDeleting', False);
    //and Environment.IsAccessGranted(GUIForm.GetResourceURI, ACM_DELETE);

  CreateStoreAndView;
  CreateFilterPanel;

  FGridPanel := TExtGridEditorGridPanel.AddTo(Items);
  FGridPanel.Region := rgCenter;
  FGridPanel.Border := False;
  FGridPanel.Header := False;
  FGridPanel.Store := FStore;
  FGridPanel.View := FGridView;
  LSelModel := TExtGridRowSelectionModel.Create;
  LSelModel.SingleSelect := True;
  FGridPanel.SelModel := LSelModel;
  FGridPanel.StripeRows := True;
  FGridPanel.Frame := True;
  FGridPanel.AutoScroll := True;
  FGridPanel.AutoWidth := True;
  FGridPanel.ColumnLines := True;
  FGridPanel.TrackMouseOver := True;
  LKeyFieldNames := Join(ViewTable.GetKeyFieldAliasedNames, ',');
  FGridPanel.On('rowdblclick', AjaxSelection(RowDblClick, LSelModel, LKeyFieldNames, LKeyFieldNames, []));

  // By default show paging toolbar unless the view is grouped.
  if ViewTable.GetBoolean('Controller/PagingTools', GetGroupingFieldName = '') then
  begin
    if GetGroupingFieldName <> '' then
      FPageRecordCount := ViewTable.GetInteger('Controller/PageRecordCount', DEFAULT_GROUPING_PAGE_RECORD_COUNT)
    else
      FPageRecordCount := ViewTable.GetInteger('Controller/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT);
    FGridPanel.Bbar := CreatePagingToolbar;
  end;

  FTopToolbar := CreateTopToolbar;
  if FTopToolbar.Items.Count = 0 then
    FreeAndNil(FTopToolbar)
  else
    FGridPanel.Tbar := FTopToolbar;
end;

procedure TKExtListPanel.CreateStoreAndView;
var
  LGroupingFieldName: string;
  LGroupingMenu: Boolean;
  LCountTemplate: string;
begin
  { TODO : investigate the row body feature }
  LGroupingFieldName := GetGroupingFieldName;
  LGroupingMenu := ViewTable.GetBoolean('Controller/Grouping/EnableMenu');
  if (LGroupingFieldName <> '') or LGroupingMenu then
  begin
    FGridView := TExtGridGroupingView.Create;
    TExtGridGroupingView(FGridView).EmptyGroupText := _('No data to display in this group.');
    { TODO : use singular and plural display labels of the form }
    //TExtGridGroupingView(FGridView).GroupTextTpl := '{text} ({[values.rs.length]} {[values.rs.length > 1 ? "Items" : "Item"]})';
    TExtGridGroupingView(FGridView).StartCollapsed := ViewTable.GetBoolean('Controller/Grouping/StartCollapsed');
    TExtGridGroupingView(FGridView).EnableGroupingMenu := LGroupingMenu;
    TExtGridGroupingView(FGridView).EnableNoGroups := LGroupingMenu;
    TExtGridGroupingView(FGridView).HideGroupedColumn := True;
    TExtGridGroupingView(FGridView).ShowGroupName := ViewTable.GetBoolean('Controller/Grouping/ShowName');
    if ViewTable.GetBoolean('Controller/Grouping/ShowCount') then
    begin
      LCountTemplate := ViewTable.GetString('Controller/Grouping/ShowCount/Template',
        '{text} ({[values.rs.length]} {[values.rs.length > 1 ? "%ITEMS%" : "%ITEM"]})');
      LCountTemplate := ReplaceText(LCountTemplate, '%ITEMS%', _(ViewTable.GetString('Controller/Grouping/ShowCount/PluralItemName', 'items')));
      LCountTemplate := ReplaceText(LCountTemplate, '%ITEM%', _(ViewTable.GetString('Controller/Grouping/ShowCount/ItemName', 'item')));
      TExtGridGroupingView(FGridView).GroupTextTpl := LCountTemplate;
    end;
    FStore := TExtDataGroupingStore.Create;
    //TExtDataGroupingStore(FStore).GroupOnSort := True;
    if LGroupingFieldName <> '' then
    begin
      TExtDataGroupingStore(FStore).GroupField := LGroupingFieldName;
      FStore.RemoteSort := False;
      FStore.SortInfo := JSObject('field:"' + ViewTable.GetString('Controller/Grouping/SortFieldName', LGroupingFieldName) + '"');
    end;
  end
  else
  begin
    FGridView := TExtGridGridView.Create;
    FStore := TExtDataStore.Create;
    FStore.RemoteSort := True;
  end;
  FGridView.EmptyText := _('No data to display.');
  FGridView.EnableRowBody := True;
  { TODO : make it configurable? }
  FGridView.ForceFit := False;

  FStore.Url := MethodURI(GetRecordPage);
  FReader :=  TExtDataJsonReader.Create(JSObject('')); // Must pass '' otherwise invalid code is generated.
  FReader.Root := 'Root';
  FReader.TotalProperty := 'Total';
  FStore.Reader := FReader;
end;

procedure TKExtListPanel.InitFieldsAndColumns;
var
  I: Integer;
  LLayout: TKLayout;
  LViewField: TKViewField;
  LLayoutName: string;

  procedure AddGridColumn(const AViewField: TKViewField);
  var
    LColumn: TExtGridColumn;
    LColumnWidth: Integer;

    function CreateColumn: TExtGridColumn;
    begin
      case AViewField.DataType of
        edtBoolean: Result := TExtGridBooleanColumn.AddTo(FGridPanel.Columns);
        edtDate:
        begin
          Result := TExtGridDateColumn.AddTo(FGridPanel.Columns);
          TExtGridDateColumn(Result).Format := DelphiDateFormatToJSDateFormat(Session.FormatSettings.ShortDateFormat);
        end;
        edtTime:
        begin
          Result := TExtGridDateColumn.AddTo(FGridPanel.Columns);
          TExtGridDateColumn(Result).Format := DelphiDateFormatToJSDateFormat(Session.FormatSettings.ShortTimeFormat);
        end;
        edtDateTime:
        begin
          Result := TExtGridDateColumn.AddTo(FGridPanel.Columns);
          TExtGridDateColumn(Result).Format :=
            DelphiDateFormatToJSDateFormat(Session.FormatSettings.ShortDateFormat) + ' ' +
            DelphiTimeFormatToJSTimeFormat(Session.FormatSettings.ShortTimeFormat);
        end;
        edtInteger:
        begin
          Result := TExtGridNumberColumn.AddTo(FGridPanel.Columns);
          TExtGridNumberColumn(Result).Format := '0';
        end;
        edtFloat, edtDecimal:
        begin
          Result := TExtGridNumberColumn.AddTo(FGridPanel.Columns);
          TExtGridNumberColumn(Result).Format := '0.00';
        end;
        edtCurrency:
        begin
          Result := TExtGridNumberColumn.AddTo(FGridPanel.Columns);
          TExtGridNumberColumn(Result).Format := '0,0.00';
        end;
      else
        Result := TExtGridColumn.AddTo(FGridPanel.Columns);
      end;
    end;

  begin
    LColumn := CreateColumn;
    LColumn.Sortable := not AViewField.IsBlob;
    LColumn.Header := AViewField.DisplayLabel;
    LColumn.Id := AViewField.AliasedName;
    { TODO : optimize size of JSON packets by using numbers? }
    LColumn.DataIndex := AViewField.AliasedName;

    LColumnWidth := AViewField.DisplayWidth;
    if LColumnWidth = 0 then
      LColumnWidth := Min(IfThen(AViewField.Size = 0, 40, AViewField.Size), 40);
    LColumn.Width := CharsToPixels(LColumnWidth);

    { TODO : add in-place editing as an option. }
    LColumn.Editable := False;
    //LColumn.Editor := ...

    if AViewField.DataType = edtBoolean then
    begin
      //LColumn.Align := alCenter;
      LColumn.RendererExtFunction := JSFunction('V', 'return "<div class=''x-grid3-check-col"+(V?"-on":"")+"''></div>";');
    end
    { TODO : implement images and hidden text }
    else if (AViewField.GetString('ImageNames') <> '') then
    begin
      if AViewField.GetBoolean('HideText') then
      begin
        LColumn.Align := alCenter;
      end
      else
      begin
        LColumn.Align := alLeft;
      end;
    end
    else if AViewField.DataType in [edtInteger, edtCurrency, edtFloat, edtDecimal] then
    begin
      LColumn.Align := alRight;
    end
    else
    begin
      LColumn.Align := alLeft;
    end;
    LColumn.Hidden := not ViewTable.IsFieldVisible(AViewField);
  end;

  procedure AddColumn(const AViewField: TKViewField);
  begin
    if ViewTable.IsFieldVisible(AViewField) or (AViewField.AliasedName = GetGroupingFieldName) then
      AddGridColumn(AViewField);
  end;

  procedure AddReaderField(const AViewField: TKViewField);
  begin
    TExtDataField.AddTo(FReader.Fields).Name := AViewField.AliasedName;
  end;

begin
  Assert(ViewTable <> nil);

  LLayoutName := ViewTable.GetString('Controller/List/Layout');
  if LLayoutName <> '' then
    LLayout := View.Catalog.Layouts.FindLayout(LLayoutName)
  else
    LLayout := ViewTable.FindLayout('List');

  if LLayout <> nil then
  begin
    for I := 0 to LLayout.ChildCount - 1 do
      AddColumn(ViewTable.FieldByAliasedName(LLayout.Children[I].AsString));
    // Add key fields anyway if they are not part of the layout.
    // If their IsVisible is False at the view or model level
    // they won't be added as grid columns anyway.
    for I := 0 to ViewTable.FieldCount - 1 do
    begin
      LViewField := ViewTable.Fields[I];
      if (LLayout.FindChild(LViewField.AliasedName) = nil) and LViewField.IsKey then
        AddColumn(LViewField);
    end;
  end
  else
  begin
    for I := 0 to ViewTable.FieldCount - 1 do
      AddColumn(ViewTable.Fields[I]);
  end;
  // All fields should be in the reader in all cases.
  for I := 0 to ViewTable.FieldCount - 1 do
    AddReaderField(ViewTable.Fields[I]);

  FGridPanel.AutoExpandColumn := ViewTable.GetString('Controller/AutoExpandFieldName');
end;

procedure TKExtListPanel.RowDblClick;
begin
  EditOrViewCurrentRecord;
end;

procedure TKExtListPanel.EditOrViewCurrentRecord;
begin
  ShowEditWindow(LocateRecordFromSession, emEditCurrentRecord);
end;

procedure TKExtListPanel.ShowEditWindow(const ARecord: TKRecord;
  const AEditMode: TKEditMode);
var
  LFormControllerType: string;

  function IsReadOnly: Boolean;
  begin
    Result := View.GetBoolean('IsReadOnly') or ViewTable.IsReadOnly or View.GetBoolean('Controller/PreventEditing');
      { TODO : implement }
      //or not Environment.IsAccessGranted(View.GetResourceURI, ACM_MODIFY);
  end;

begin
  Assert(Assigned(ARecord));
  Assert(View <> nil);
  Assert(ViewTable <> nil);

  FreeAndNil(FEditHostWindow);
  FEditHostWindow := TKExtModalWindow.Create;
  FEditHostWindow.Width := ViewTable.GetInteger('Controller/PopupWindow/Width', FEditHostWindow.Width);
  FEditHostWindow.Height := ViewTable.GetInteger('Controller/PopupWindow/Height', FEditHostWindow.Height);
  FEditHostWindow.ResizeHandles := 'n s';

  if AEditMode = emNewRecord then
    FEditHostWindow.Title := Format(_('New %s'), [ViewTable.DisplayLabel])
  else if IsReadOnly then
    FEditHostWindow.Title := Format(_('View %s'), [ViewTable.DisplayLabel])
  else
    FEditHostWindow.Title := Format(_('Edit %s'), [ViewTable.DisplayLabel]);
  //FEditHostWindow.On('close', Ajax(EditWindowClosed, ['Window', '%0.nm']));

  LFormControllerType := View.GetString('Controller/FormController/Type', 'Form');
  FreeAndNilEFIntf(FFormController);
  FFormController := TKControllerFactory.Instance.CreateObject(LFormControllerType);
  try
    Session.GarbageDelete(FFormController.AsObject); // We're going to free it ourselves.
    FFormController.View := View;
    FFormController.Config.SetObject('Sys/Container', FEditHostWindow);
    FFormController.Config.SetObject('Sys/Store', ServerStore);
    FFormController.Config.SetObject('Sys/Record', ARecord);
    FFormController.Config.SetObject('Sys/ViewTable', ViewTable);
    FFormController.Config.SetObject('Sys/HostWindow', FEditHostWindow);
    (FFormController as IEFSubject).AttachObserver(Self);
    if AEditMode = emNewRecord then
      FFormController.Config.SetString('Sys/Operation', 'Add');
    FFormController.Display;
  except
    FreeAndNilEFIntf(FFormController);
    raise;
  end;
  FEditHostWindow.Show;
end;

procedure TKExtListPanel.UpdateObserver(const ASubject: IEFSubject;
  const AContext: string);
begin
  inherited;
  if (AContext = 'FilterChanged') then
    RefreshData;
  if (AContext = 'Confirmed') and Supports(ASubject.AsObject, IKController) then
    RefreshData;
end;

function TKExtListPanel.LocateRecordFromSession: TKRecord;
var
  LKeyValues: TStringDynArray;
  I: Integer;
begin
  Assert(ViewTable <> nil);
  Assert(ServerStore.RecordCount > 0);

  SetLength(LKeyValues, ServerStore.Key.FieldCount);
  for I := 0 to ServerStore.Key.FieldCount - 1 do
  begin
    { TODO : support data types }
    LKeyValues[I] := Session.Query[ServerStore.Key.Fields[I].Name];
  end;
  Result := ServerStore.Records.GetRecordByKey(LKeyValues);
//  if LField.DataType = edtInteger then
//    LKeyValues[I] := Session.QueryAsInteger[LAliasedFieldName]
//  else if LField.DataType in [edtCurrency, edtFloat] then
//    LKeyValues[I] := Session.QueryAsDouble[LAliasedFieldName]
//  else if LField.DataType = edtBoolean then
//    LKeyValues[I] := Session.QueryAsDouble[LAliasedFieldName]
//  else if LField.DataType in [edtDate, edtTime, edtDateTime] then
//    LKeyValues[I] := Session.QueryAsTDateTime[LAliasedFieldName]
//  else
//    LKeyValues[I] := Session.Query[LAliasedFieldName];
end;

procedure TKExtListPanel.NewRecord(This: TExtButton; E: TExtEventObjectSingleton);
begin
  ShowEditWindow(nil, emNewRecord);
end;

procedure TKExtListPanel.LoadData;
begin
  inherited;
  Assert(Assigned(FGridPanel));

  if FGridPanel.Columns.Count = 0 then
    InitFieldsAndColumns;
  if AutoLoadData then
    RefreshData;
end;

function TKExtListPanel.GetRefreshJSCode: string;
begin
  Assert(Assigned(FStore));

  if Assigned(FPagingToolbar) then
    Result := FPagingToolbar.JSName + '.dorefresh();'
  else
    Result := FStore.JSName + '.load({params:{start:0,limit:' + IntToStr(FPageRecordCount) + ',Obj:"' + JSName + '"}});';
end;

procedure TKExtListPanel.RefreshData;
begin
  Assert(Assigned(FStore));

  if Assigned(FPagingToolbar) then
    FPagingToolbar.DoRefresh
  else
    FStore.Load(JSObject('params:{start:0,limit:' + IntToStr(FPageRecordCount) + ',Obj:"' + JSName + '"}'));
end;

{ TKExtFilterPanel }

function TKExtFilterPanel.GetFilterExpression: string;
var
  LIntf: IKExtFilter;
  I: Integer;
  LExpression: string;
begin
  Result := '';
  for I := 0 to Items.Count - 1 do
  begin
    if Supports(Items[I], IKExtFilter, LIntf) then
    begin
      LExpression := LIntf.GetExpression;
      if LExpression <> '' then
      begin
        if Result = '' then
          Result := '(' + LExpression + ')'
        else
          Result := Result + ' ' + FConnector + ' ' + '(' + LExpression + ')';
      end;
    end;
  end;
end;

initialization
  TKControllerRegistry.Instance.RegisterClass('List', TKExtListPanel);

finalization
  TKControllerRegistry.Instance.UnregisterClass('List');

end.