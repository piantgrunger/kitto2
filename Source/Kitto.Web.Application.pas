{-------------------------------------------------------------------------------
   Copyright 2012-2017 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

unit Kitto.Web.Application;

interface

uses
  Types
  , SysUtils
  , Classes
  , EF.Macros
  , Generics.Collections
  , Rtti
  , EF.Tree
  , EF.Intf
  , EF.ObserverIntf
  , Kitto.Auth
  , Kitto.AccessControl
  , Kitto.Config
  , Kitto.Metadata.Views
  , Kitto.JS.Base
  , Kitto.JS
  , Kitto.Web.Server
  , Kitto.Web.URL
  , Kitto.Web.Request
  , Kitto.Web.Response
  , Kitto.Ext.Base
  , Kitto.Ext.Controller
  ;

type
  TKWebApplication = class;

  TKApplicationMacroExpander = class(TEFTreeMacroExpander)
  private
    FApplication: TKWebApplication;
  strict protected
    function InternalExpand(const AString: string): string; override;
  public
    constructor Create(const AApplication: TKWebApplication); reintroduce;
  end;

  TKWebApplication = class(TKWebRoute)
  strict private
    FConfig: TKConfig;
    FRttiContext: TRttiContext;
    FPath: string;
    FLoginNode: TEFNode;
    FOwnsLoginNode: Boolean;
    FTheme: string;
    FExtJSPath: string;
//    FExtJSLocalPath: string;
    FAdditionalRefs: TList<string>;
    FMacroExpander: TKApplicationMacroExpander;
    FResourcePath: string;
    FResourceLocalPath1: string;
    FResourceLocalPath2: string;
    FAuthenticator: TKAuthenticator;
    FAccessController: TKAccessController;
    class threadvar FCurrent: TKWebApplication;
    class var FOnCreateHostWindow: TFunc<TJSBase, IJSControllerContainer>;
    function GetDefaultHomeViewNodeNames(const AViewportWidthInInches: Integer; const ASuffix: string): TStringDynArray;
    procedure Home;
    procedure FreeLoginNode;
    procedure ServeHomePage;
    function FindOpenController(const AView: TKView): IJSController;
    function GetMainPageTemplate: string;
    function GetManifestFileName: string;
    procedure ClearStatus;
    function GetLibraryTags: string;
    procedure SetViewportContent;
    function GetCustomJS: string;
    function GetViewportContent: string;
    procedure ActivateInstance;

    procedure DeactivateInstance;
    procedure Reload;
    function GetObjectFromURL(const AURL: TKURL): TObject;
    class function GetCurrent: TKWebApplication; static;
    class procedure SetCurrent(const AValue: TKWebApplication); static;
    function CallObjectMethod(const AObject: TObject; const AMethodName: string): Boolean;
    function GetViewportWidthInInches: TJSExpression;
    class function CreateHostWindow(const AOwner: TJSBase): IJSControllerContainer; static;
    function GetAuthenticator: TKAuthenticator;
    function GetAccessController: TKAccessController;
    procedure InitConfig;
    /// <summary>
    ///  Adds a .png extension to the resource name.
    ///  ASuffix, if specified, is added before the file extension.
    ///  If the image name ends with _ and a two-digit number among 16, 24, 32, and 48,
    ///  then the suffix is added before the _.
    /// </summary>
    class function AdaptImageName(const AResourceName: string; const ASuffix: string = ''): string;
  public
    const DEFAULT_VIEWPORT_WIDTH = 480;
    class constructor Create;
    class destructor Destroy;
    procedure AfterConstruction; override;
    destructor Destroy; override;

    function HandleRequest(const ARequest: TKWebRequest; const AResponse: TKWebResponse; const AURL: TKURL): Boolean; override;
    procedure UpdateObserver(const ASubject: IEFSubject; const AContext: string = ''); override;
    procedure AddedToServer(const AServer: TKWebServer; const AIndex: Integer); override;

    property Config: TKConfig read FConfig;
    procedure ReloadConfig;

    function GetHomeView(const AViewportWidthInInches: Integer): TKView;
    procedure DisplayView(const AName: string); overload;
    procedure DisplayView(const AView: TKView); overload;
    function FindPageTemplate(const APageName: string): string;
    function GetPageTemplate(const APageName: string): string;
    function DisplayNewController(const AView: TKView; const AForceModal: Boolean = False;
      const AAfterCreateWindow: TProc<IJSContainer> = nil;
      const AAfterCreate: TProc<IJSController> = nil): IJSController;
    property Path: string read FPath;
    property Theme: string read FTheme;
    property ExtJSPath: string read FExtJSPath;

    class property Current: TKWebApplication read GetCurrent write SetCurrent;

    class property OnCreateHostWindow: TFunc<TJSBase, IJSControllerContainer> read FOnCreateHostWindow write FOnCreateHostWindow;

    /// <summary>
    ///  Returns the URL for the specified resource, based on the first
    ///  existing file in the ordered list of resource folders. If no existing
    ///  file is found, an exception is raised.
    /// </summary>
    /// <param name="AResourceFileName">
    ///  Resource file name relative to the resource folder. Examples:
    ///  some_image.png, js\some_library.js.
    /// </param>
    function GetResourceURL(const AResourceFileName: string): string;

    /// <summary>Returns the URL for the specified resource, based on the first
    /// existing file in the ordered list of resource folders. If no existing
    /// file is found, returns ''.</summary>
    /// <param name="AResourceFileName">Resource file name relative to the
    /// resource folder. Examples: some_image.png, js\some_library.js.</param>
    function FindResourceURL(const AResourceFileName: string): string;

    /// <summary>
    ///   Returns the full pathname for the specified resource, based on the first
    ///   existing file in the ordered list of resource folders. If no existing
    ///   file is found, an exception is raised.
    /// </summary>
    /// <param name="AResourceFileName">
    ///   Resource file name relative to the resource folder. Examples:
    ///   some_image.png, js\some_library.js.
    /// </param>
    function GetResourcePathName(const AResourceFileName: string): string;

    /// <summary>
    ///  Returns the full pathname for the specified resource, based on
    ///  the first existing file in the ordered list of resource folders. If no
    ///  existing file is found, returns ''.
    /// </summary>
    /// <param name="AResourceFileName">
    ///  Resource file name relative to the resource folder.
    ///  Examples: some_image.png, js\some_library.js.
    /// </param>
    function FindResourcePathName(const AResourceFileName: string): string;

    function GetImageURL(const AResourceName: string; const ASuffix: string = ''): string;
    function FindImageURL(const AResourceName: string; const ASuffix: string = ''): string;

    function GetImagePathName(const AResourceName: string; const ASuffix: string = ''): string;
    function FindImagePathName(const AResourceName: string; const ASuffix: string = ''): string;

    procedure ReloadOrDisplayHomeView;
    function GetLoginView: TKView;
    procedure DisplayHomeView;
    procedure DisplayLoginView;
    procedure Toast(const AMessage: string);
    procedure Navigate(const AURL: string);
    /// <summary>
    ///  <para>
    ///   Adds to the current session a style class named after AView's
    ///   ImageName (or the specified custom AImageName) plus a '_img'
    ///   suffix, that sets background:url to the URL of the view's image.
    ///  </para>
    ///  <para>
    ///   The style class can have an optional custom prefix before the name
    ///   and custom rules attached to it.
    ///  </para>
    /// </summary>
    /// <returns>
    ///  Returns the class name so that it can be assigned to a component's
    ///  IconCls property.
    /// </returns>
    function SetViewIconStyle(const AView: TKView; const AImageName: string = '';
      const ACustomPrefix: string = ''; const ACustomRules: string = ''): string;
    function SetIconStyle(const ADefaultImageName: string; const AImageName: string = '';
      const ACustomPrefix: string = ''; const ACustomRules: string = ''): string;

    procedure DownloadFile(const AServerFileName, AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    procedure DownloadStream(const AStream: TStream; const AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    procedure DownloadBytes(const ABytes: TBytes; const AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    /// <summary>
    ///  Checks user credentials (fetched from Query parameters UserName and Passwords)
    ///  and returns True if the current authenticator allows them, or if the
    ///  user was already authenticated in this session.
    /// </summary>
    function Authenticate: Boolean;

    /// <summary>
    ///  Call this in the initialization section of a unit defining a controller
    ///  to ensure that additional javascript or css files are included.
    /// </summary>
    procedure AddAdditionalRef(const APath: string);
    procedure MethodCallError(const AMessage, AMethodName, AParams: string);
    procedure MethodNotFoundError(const AMethodName: string);
    procedure Error(const AMessage: string);
    function GetMethodURL(const AObjectName, AMethodName: string): string;
    /// <summary>
    ///  Returns the Home URL of the Kitto application assuming the URL is
    ///  visited from localhost.
    /// </summary>
    function GetHomeURL(const ATCPPort: Integer): string;
    /// <summary>
    ///  True if tooltips are enabled for the application. By default, tooltips
    ///  are enabled for desktop browsers and disabled for mobile browsers.
    /// </summary>
    function TooltipsEnabled: Boolean;

    procedure DelayedHome;
    procedure Logout;
  end;

implementation

uses
  StrUtils
  , IOUtils
  , NetEncoding
  , Variants
  , EF.StrUtils
  , EF.Localization
  , EF.Types
  , Ext.Base
  , Kitto.Types
  , Kitto.JS.Formatting
  , Kitto.Web.Types
  , Kitto.Web.Session
  ;

{ TKApplicationMacroExpander }

constructor TKApplicationMacroExpander.Create(const AApplication: TKWebApplication);
begin
  Assert(Assigned(AApplication));

  // We will pass Session.AuthData dynamically as needed, so we initialize the
  // expander with nil. We inherit from TEFTreeExpander only to inherit its
  // functionality.
  inherited Create(nil, 'Auth');
  FApplication := AApplication;
end;

function TKApplicationMacroExpander.InternalExpand(const AString: string): string;
const
  IMAGE_MACRO_HEAD = '%IMAGE(';
  MACRO_TAIL = ')%';
var
  LPosHead: Integer;
  LPosTail: Integer;
  LName: string;
begin
  Result := inherited InternalExpand(AString);
  if Session <> nil then
  begin
    Result := ExpandMacros(Result, '%SESSION_ID%', Session.SessionId);
    Result := ExpandMacros(Result, '%LANGUAGE_ID%', Session.Language);
    // Expand %Auth:*%.
    Result := ExpandTreeMacros(Result, Session.AuthData);
  end;

  if FApplication <> nil then
  begin
    LPosHead := Pos(IMAGE_MACRO_HEAD, Result);
    if LPosHead > 0 then
    begin
      LPosTail := PosEx(MACRO_TAIL, Result, LPosHead + 1);
      if LPosTail > 0 then
      begin
        LName := Copy(Result, LPosHead + Length(IMAGE_MACRO_HEAD),
          LPosTail - (LPosHead + Length(IMAGE_MACRO_HEAD)));
        Result := Copy(Result, 1, LPosHead - 1) + FApplication.GetImageURL(LName)
          + InternalExpand(Copy(Result, LPosTail + Length(MACRO_TAIL), MaxInt));
      end;
    end;
  end;
end;

{ TWebKApplication }

function TKWebApplication.GetObjectFromURL(const AURL: TKURL): TObject;
var
  LJSName: string;
begin
  LJSName := AURL.ExtractObjectName;
  if LJSName = '' then
    Result := Self
  else
    Result := Session.ObjectSpace.FindChildByJSName(LJSName);
  if not Assigned(Result) then
    raise Exception.CreateFmt('Handler object %s for method %s not found in session.', [LJSName, AURL.Document]);
end;

procedure TKWebApplication.AfterConstruction;
begin
  inherited;
  FOwnsLoginNode := False;
  FRttiContext := TRttiContext.Create;
  FAdditionalRefs := TList<string>.Create;
  InitConfig;
end;

destructor TKWebApplication.Destroy;
begin
  FreeLoginNode;
  FreeAndNil(FAuthenticator);
  FreeAndNil(FAccessController);
  FreeAndNil(FConfig);
  FreeAndNil(FAdditionalRefs);
  inherited;
end;

procedure TKWebApplication.InitConfig;
begin
  FConfig := TKConfig.Create;
  FMacroExpander := TKApplicationMacroExpander.Create(Self);
  FConfig.MacroExpansionEngine.AddExpander(FMacroExpander);
  FTheme := FConfig.Config.GetString('ExtJS/Theme', 'triton');
  FPath := FConfig.Config.GetString('AppPath', '/' + Config.AppName.ToLower);
  FResourcePath := FPath + '/res';
  FExtJSPath := FResourcePath + '/ext';
//  FExtJSLocalPath := FConfig.Config.GetString('ExtJS/Path', TPath.Combine(FConfig.SystemHomePath, TPath.Combine('Resources', 'ext')));
  FResourceLocalPath1 := TPath.Combine(FConfig.AppHomePath, 'Resources');
  FResourceLocalPath2 := TPath.Combine(FConfig.SystemHomePath, 'Resources');
end;

procedure TKWebApplication.ReloadConfig;
begin
  FreeLoginNode;
  FreeAndNil(FAuthenticator);
  FreeAndNil(FAccessController);
  FreeAndNil(FConfig);
  InitConfig;
end;

procedure TKWebApplication.AddAdditionalRef(const APath: string);
begin
  FAdditionalRefs.Add(APath);
end;

procedure TKWebApplication.AddedToServer(const AServer: TKWebServer; const AIndex: Integer);
begin
  inherited;
  // Resources now share the application's path, so they must be resolved before application calls.
  AServer.AddRoute(TKMultipleStaticWebRoute.Create(
    FResourcePath + '/',
    [FResourceLocalPath1, FResourceLocalPath2]), AIndex);

  // This route needs to be added before all others, as some URLs generated by
  // Ext.Loader may be misinterpreted by the application as method calls.
  // Case in point: the DateTimeField.js has a Ext.define() call that includes
  // requires: ['Ext.ux.DateTimePicker']. Since they are using the Ext namespace,
  // and Ext.Loader does not appear to support remapping sub-namespaces, we can
  // only resort to this hack in order to serve the file correctly for the time being.
  // Reusing AIndex means we add the routes in reverse order.
  AServer.AddRoute(TKStaticWebRoute.Create(
    FPath + '/Ext/ux/*',
    TPath.Combine(FConfig.SystemHomePath, TPath.Combine('Resources', 'js\Ext\ux'))), AIndex);

//  AServer.AddRoute(TKStaticWebRoute.Create(
//    FExtJSPath + '/*',
//    FExtJSLocalPath));
end;

procedure TKWebApplication.FreeLoginNode;
begin
  // Free login node only if one was manufactured.
  if FOwnsLoginNode and Assigned(FLoginNode) then
  begin
    Config.Views.DeleteNonpersistentObject(FLoginNode);
    FreeAndNil(FLoginNode);
  end;
  FLoginNode := nil;
end;

function TKWebApplication.GetHomeURL(const ATCPPort: Integer): string;
begin
  Result := 'http://localhost';
  if ATCPPort <> 80 then
    Result := Result + ':' + ATCPPort.ToString;
  Result := Result + FPath + '/home';
end;

function TKWebApplication.GetHomeView(const AViewportWidthInInches: Integer): TKView;
var
  LNodeNames: TStringDynArray;
begin
  if Session.HomeViewNodeName <> '' then
  begin
    SetLength(LNodeNames,1);
    LNodeNames[0] := Session.HomeViewNodeName;
  end
  else
    LNodeNames := GetDefaultHomeViewNodeNames(AViewportWidthInInches, 'View');
  Result := Config.Views.FindViewByNode(Config.Config.FindNode(LNodeNames));
  if not Assigned(Result) then
    Result := Config.Views.ViewByName(GetDefaultHomeViewNodeNames(AViewportWidthInInches, ''));
end;

function TKWebApplication.GetLoginView: TKView;
begin
  if not Assigned(FLoginNode) then
  begin
    FOwnsLoginNode := False;
    FLoginNode := Config.Config.FindNode('Login');
    if not Assigned(FLoginNode) then
    begin
      Result := Config.Views.FindView('Login');
      if Assigned(Result) then
        Exit;

      FLoginNode := TEFNode.Create('Login');
      try
        FOwnsLoginNode := True;
        FLoginNode.SetString('Controller', 'Login');
      except
        FreeAndNil(FLoginNode);
        FOwnsLoginNode := False;
        raise;
      end;
    end;
  end;
  Result := Config.Views.FindViewByNode(FLoginNode);
  if not Assigned(Result) then
    raise Exception.Create('Login View not found');
end;

function TKWebApplication.GetDefaultHomeViewNodeNames(const AViewportWidthInInches: Integer;
  const ASuffix: string): TStringDynArray;
begin
  case AViewportWidthInInches of
    0..5:
    begin
      SetLength(Result, 3);
      Result[0] := 'HomeTiny' + ASuffix;
      Result[1] := 'HomeSmall' + ASuffix;
      Result[2] := 'Home' + ASuffix;
    end;
    6..10:
    begin
      SetLength(Result, 2);
      Result[0] := 'HomeSmall' + ASuffix;
      Result[1] := 'Home' + ASuffix;
    end
  else
    begin
      SetLength(Result, 1);
      Result[0] := 'Home' + ASuffix;
    end;
  end;
end;

function TKWebApplication.DisplayNewController(const AView: TKView; const AForceModal: Boolean;

  const AAfterCreateWindow: TProc<IJSContainer>;
  const AAfterCreate: TProc<IJSController>): IJSController;
var
  LIsSynchronous: Boolean;
  LIsModal: Boolean;
  LWindow: IJSControllerContainer;
begin
  Assert(Assigned(AView));

  // If there's no view host, we treat all views as windows.
  LIsModal := AForceModal or not Assigned(Session.ControllerContainer) or AView.GetBoolean('Controller/IsModal');
  if Assigned(Session.ControllerHostWindow) then
  begin
    Session.ControllerHostWindow.AsJSObject.Delete;
    Session.ControllerHostWindow.AsObject.Free;
    Session.ControllerHostWindow := nil;
  end;
  { TODO :
  If we added the ability to change owner after object creation,
  this code could be simplified a lot by only creating the window if needed. }
  if LIsModal then
  begin
    LWindow := CreateHostWindow(Session.ObjectSpace);
    Session.ControllerHostWindow := LWindow;
    if Assigned(AAfterCreateWindow) then
      AAfterCreateWindow(LWindow);
    Result := TKExtControllerFactory.Instance.CreateController(Session.ObjectSpace, AView, LWindow);
    if Assigned(AAfterCreate) then
      AAfterCreate(Result);
    if not Result.Config.GetBoolean('Sys/SupportsContainer') then
    begin
      Session.ControllerHostWindow.AsJSObject.Delete;
      Session.ControllerHostWindow.AsJSObject.Free;
      Session.ControllerHostWindow := nil;
    end
    else
    begin
      { TODO : remove dependency from TKExtWindowControllerBase }
//      set view
//      is autosize
      LWindow.SetActiveSubController(Result);
      if TKExtWindowControllerBase(LWindow).Title = '' then
        TKExtWindowControllerBase(LWindow).Title := _(AView.DisplayLabel);
      TKExtWindowControllerBase(LWindow).Closable := AView.GetBoolean('Controller/AllowClose', True);
      Result.Config.SetObject('Sys/HostWindow', LWindow.AsObject);
//      Result.Config.SetBoolean('Sys/HostWindow/AutoSize',
      TKExtWindowControllerBase(LWindow).SetSizeFromTree(AView, 'Controller/PopupWindow/');
    end;
  end
  else
  begin
    Assert(Assigned(Session.ControllerContainer));
    Result := TKExtControllerFactory.Instance.CreateController(Session.ObjectSpace, AView, Session.ControllerContainer);
    //Assert(Result.Config.GetBoolean('Sys/SupportsContainer'));
  end;
  LIsSynchronous := Result.IsSynchronous;
  if not LIsSynchronous then
    Session.OpenControllers.Add(Result);
  try
    Result.Display;
    if Assigned(Session.ControllerHostWindow) and not LIsSynchronous then
      TKExtControllerHostWindow(Session.ControllerHostWindow).Show;
  except
    if Assigned(Session.ControllerHostWindow) and not LIsSynchronous then
      TKExtControllerHostWindow(Session.ControllerHostWindow).Hide;
    Session.OpenControllers.Remove(Result);
    FreeAndNilEFIntf(Result);
    raise;
  end;
  // Synchronous controllers end their life inside Display.
  if LIsSynchronous then
    NilEFIntf(Result);
end;

class function TKWebApplication.CreateHostWindow(const AOwner: TJSBase): IJSControllerContainer;
begin
  if Assigned(FOnCreateHostWindow) then
    Result := FOnCreateHostWindow(AOwner)
  else
    raise Exception.Create('Couldn''t create host window');
end;

procedure TKWebApplication.DisplayView(const AName: string);
begin
  Assert(AName <> '');

  DisplayView(Config.Views.ViewByName(AName));
end;

function TKWebApplication.FindOpenController(const AView: TKView): IJSController;
var
  I: Integer;
begin
  Assert(Assigned(AView));

  Result := nil;
  for I := 0 to Session.OpenControllers.Count - 1 do
  begin
    if Session.OpenControllers[I].View = AView then
      Exit(Session.OpenControllers[I]);
  end;
end;

procedure TKWebApplication.DisplayView(const AView: TKView);
var
  LController: IJSController;
begin
  Assert(Assigned(AView));

  if AView.IsAccessGranted(ACM_VIEW) then
  begin
    try
      if AView.GetBoolean('Controller/AllowMultipleInstances') then
        LController := DisplayNewController(AView)
      else
      begin
        LController := FindOpenController(AView);
        if not Assigned(LController) then
          LController := DisplayNewController(AView);
      end;
      if Assigned(LController) and Assigned(Session.ControllerContainer) and LController.Config.GetBoolean('Sys/SupportsContainer') then
        Session.ControllerContainer.SetActiveSubController(LController);
    finally
      ClearStatus;
    end;
  end;
end;

function TKWebApplication.CallObjectMethod(const AObject: TObject; const AMethodName: string): Boolean;
var
  LInfo : TRttiType;
  LMethod : TRttiMethod;
begin
  LInfo := FRttiContext.GetType(AObject.ClassType);
  LMethod := LInfo.GetMethod(AMethodName);
  Result := Assigned(LMethod);
  if Result then
    LMethod.Invoke(AObject, []);
end;

procedure TKWebApplication.ClearStatus;
begin
  if Assigned(Session.StatusHost) then
    Session.StatusHost.ClearStatus;
end;

class constructor TKWebApplication.Create;
begin
  TKConfig.OnGetInstance :=
    function: TKConfig
    begin
      if FCurrent <> nil then
        Result := FCurrent.Config
      else
        Result := nil;
    end;
end;

class procedure TKWebApplication.SetCurrent(const AValue: TKWebApplication);
begin
  FCurrent := AValue;
end;

function TKWebApplication.SetIconStyle(const ADefaultImageName: string;
  const AImageName: string; const ACustomPrefix: string;
  const ACustomRules: string): string;
var
  LIconURL: string;
  LRule: string;
  LSelector: string;
begin
  Assert(TKWebRequest.Current.IsAjax);

  Result := IfThen(AImageName <> '', AImageName, ADefaultImageName);
  LIconURL := GetImageURL(Result);
  Result := ACustomPrefix + Result + '_img';
  // The !important rule allows to use a non-specific selector, so that the icon
  // can be shared by different components.
  // no-repeat is added because some components (such as buttons) repeat by default
  // (others, such as menu items and tree nodes, don't).
  LSelector := '.' + Result;
  LRule := '{background: url(' + LIconURL + ') no-repeat left !important;' + ACustomRules + '}';
  TKWebResponse.Current.Items.ExecuteJSCode(Format('addStyleRule("%s", "%s");', [LSelector, LRule]));
end;

function TKWebApplication.SetViewIconStyle(const AView: TKView; const AImageName, ACustomPrefix, ACustomRules: string): string;
begin
  Assert(Assigned(AView));

  Result := SetIconStyle(AView.ImageName, AImageName, ACustomPrefix, ACustomRules);
end;

procedure TKWebApplication.DownloadBytes(const ABytes: TBytes; const AFileName, AContentType: string; const AInline: Boolean);
begin
  DownloadStream(TBytesStream.Create(ABytes), AFileName, AContentType, AInline);
end;

procedure TKWebApplication.DownloadFile(const AServerFileName, AFileName, AContentType: string; const AInline: Boolean);
begin
  DownloadStream(TFileStream.Create(AServerFileName, fmOpenRead, fmShareDenyNone), AFileName, AContentType, AInline);
end;

procedure TKWebApplication.DownloadStream(const AStream: TStream; const AFileName, AContentType: string; const AInline: Boolean);
begin
  if Assigned(AStream) then
  begin
    TKWebResponse.Current.SetCustomHeader('Content-Disposition',
      Format('%s; filename="%s"', [IfThen(AInline, 'inline', 'attachment'), ExtractFileName(AFileName)]));
    TKWebResponse.Current.ReplaceContentStream(AStream);
    if AContentType <> '' then
      TKWebResponse.Current.ContentType := AContentType
    else
      TKWebResponse.Current.ContentType := GetFileMimeType(AFileName);
  end;
end;

{ TKWebApplication }

function TKWebApplication.HandleRequest(const ARequest: TKWebRequest; const AResponse: TKWebResponse; const AURL: TKURL): Boolean;
var
  LHandlerObject: TObject;

  function IsHomeRequest: Boolean;
  begin
    Result := not TKWebRequest.Current.IsAjax and ((AURL.Document = '') or (AURL.Document = 'home'));
  end;

begin
  Assert(Assigned(ARequest));
  Assert(Assigned(AResponse));

  Result := False;
  if StrMatchesEx(AURL.Path, FPath + '/*') then
  begin
    ActivateInstance;
    try
      try
        try
          if IsHomeRequest then
          begin
            Home;
            Result := True;
          end
          else
          begin
            // Try to execute method.
            LHandlerObject := GetObjectFromURL(AURL);
            Result := CallObjectMethod(LHandlerObject, AURL.Document);
          end;
        except
          on E: Exception do
          begin
            MethodCallError(E.Message, AURL.Document, AURL.Params);
            Result := True;
          end;
        end;
        if not Result then
          MethodNotFoundError(AURL.Path + '/' + AURL.Document);
        AResponse.Render;
      except
        on E: Exception do
        begin
          Error(E.Message);
          AResponse.Render;
          Result := True;
        end;
      end;
    finally
      DeactivateInstance;
    end;
  end;
end;

function TKWebApplication.GetMethodURL(const AObjectName, AMethodName: string): string;
begin
  Result := FPath + '/' + IfThen(AObjectName <> '',  AObjectName + '/', '') + AMethodName;
end;

procedure TKWebApplication.ActivateInstance;
begin
  FCurrent := Self;
  TEFMacroExpansionEngine.OnGetInstance :=
    function: TEFMacroExpansionEngine
    begin
      Result := Config.MacroExpansionEngine
    end;
  TKAuthenticator.Current := GetAuthenticator;
  TKAccessController.Current := GetAccessController;
end;

procedure TKWebApplication.DeactivateInstance;
begin
  FCurrent := nil;
  TEFMacroExpansionEngine.OnGetInstance := nil;
  TKAuthenticator.Current := nil;
  TKAccessController.Current := nil;
end;

procedure TKWebApplication.DelayedHome;
begin
  if TKWebRequest.Current.IsBrowserIPhone then
    Session.ViewportWidthInInches := 4
  else if TKWebRequest.Current.IsBrowserIPad then
    Session.ViewportWidthInInches := 8
  else
    Session.ViewportWidthInInches := StrToIntDef(TKWebRequest.Current.GetQueryField('vpWidthInches'), 0);

  Session.ViewportWidth := Session.GetDefaultViewportWidth();
  TKWebResponse.Current.Items.ExecuteJSCode(Session.ObjectSpace, 'setViewportWidth(' + IntToStr(Session.ViewportWidth) + ');');
  // Try authentication with default credentials, if any, and skip login
  // window if it succeeds.
  if Authenticate then
    DisplayHomeView
  else
    DisplayLoginView;
  Session.RefreshingLanguage := False;
end;

function TKWebApplication.Authenticate: Boolean;
var
  LAuthData: TEFNode;
  LUserName: string;
  LPassword: string;
  LAuthenticator: TKAuthenticator;
begin
  LAuthenticator := GetAuthenticator;

  if LAuthenticator.IsAuthenticated then
    Result := True
  else
  begin
    LAuthData := TEFNode.Create;
    try
      LAuthenticator.DefineAuthData(LAuthData);
      LUserName := TKWebRequest.Current.GetQueryField('UserName');
      if LUserName <> '' then
        LAuthData.SetString('UserName', LUserName);
      LPassword := TKWebRequest.Current.GetQueryField('Password');
      if LPassword <> '' then
        LAuthData.SetString('Password', LPassword);
      Result := LAuthenticator.Authenticate(LAuthData);
    finally
      LAuthData.Free;
    end;
  end;
end;

procedure TKWebApplication.ReloadOrDisplayHomeView;
var
  LNewLanguageId: string;
begin
  LNewLanguageId := TKWebRequest.Current.QueryFields.Values['Language'];
  if (LNewLanguageId <> '') and (LNewLanguageId <> Session.Language) then
  begin
    Session.RefreshingLanguage := True;
    Session.Language := LNewLanguageId;
  end;
  DisplayHomeView;
end;

class destructor TKWebApplication.Destroy;
begin
  TKConfig.OnGetInstance := nil;
end;

procedure TKWebApplication.DisplayHomeView;
var
  LHomeView: TKView;
begin
  if Assigned(Session.HomeController) then
  begin
    Session.HomeController.AsObject.Free;
    Session.HomeController := nil;
  end;
  LHomeView := GetHomeView(Session.ViewportWidthInInches);

  Session.HomeController := TKExtControllerFactory.Instance.CreateController(Session.ObjectSpace, LHomeView, nil);
  TKWebResponse.Current.Items.ExecuteJSCode(Session.HomeController.AsJSObject, 'var kittoHomeContainer = ' + Session.HomeController.AsJSObject.JSName + ';');
  Session.HomeController.Display;

  if Session.AutoOpenViewName <> '' then
  begin
    DisplayView(Session.AutoOpenViewName);
    Session.AutoOpenViewName := '';
  end;

  { TODO : remove dependency }
  if Session.HomeController is TExtContainer then
    TExtContainer(Session.HomeController).UpdateLayout;
end;

procedure TKWebApplication.DisplayLoginView;
var
  LLoginView: TKView;
  LType: string;
begin
  if Assigned(Session.LoginController) then
  begin
    Session.LoginController.AsObject.Free;
    Session.LoginController := nil;
  end;
  LLoginView := TKWebApplication.Current.GetLoginView;
  if LLoginView.ControllerType = '' then
    LType := 'Login'
  else
    LType := '';
  Session.LoginController := TKExtControllerFactory.Instance.CreateController(Session.ObjectSpace, LLoginView, nil, nil, Self, LType);
  Session.LoginController.Display;

  { TODO : remove dependency }
  if Session.LoginController is TExtContainer then
    TExtContainer(Session.LoginController).UpdateLayout;
end;

procedure TKWebApplication.Home;

  procedure SetAjaxTimeout;
  var
    LTimeout: TEFNode;
  begin
    LTimeout := Config.Config.FindNode('ExtJS/AjaxTimeout');
    if Assigned(LTimeout) then
      TKWebResponse.Current.Items.ExecuteJSCode(Session.ObjectSpace, Format('Ext.Ajax.setTimeout(%d);', [LTimeout.AsInteger]));
  end;

begin
  if TKWebRequest.Current.IsAjax then
    raise Exception.Create('Cannot call Home page in an Ajax request.');

  if not Session.RefreshingLanguage then
    GetAuthenticator.Logout;

  Session.HomeViewNodeName := TKWebRequest.Current.QueryFields.Values['home'];
  SetViewportContent;
  TKWebResponse.Current.Items.ExecuteJSCode(Session.ObjectSpace, 'kittoInit();');
  SetAjaxTimeout;
  if TooltipsEnabled then
    ExtQuickTips.Init(True)
  else
    ExtQuickTips.Disable;

  if not Session.RefreshingLanguage then
    Session.SetLanguageFromQueriesOrConfig(Config);

  Session.AutoOpenViewName := TKWebRequest.Current.QueryFields.Values['view'];
//  if FAutoOpenViewName <> '' then
//    Query['view'] := '';

  TKWebResponse.Current.Items.AjaxCallMethod(Session.ObjectSpace).SetMethod(DelayedHome)
    .AddParam('vpWidthInches', GetViewportWidthInInches);

  ServeHomePage;
end;

function TKWebApplication.GetViewportWidthInInches: TJSExpression;
begin
  Result := TJSExpression.Create(Session.ObjectSpace);
  Result.Text := 'getViewportWidthInInches()';
end;

procedure TKWebApplication.Error(const AMessage: string);
begin
  TKWebResponse.Current.Items.Clear;
  if TKWebRequest.Current.IsAjax then
    TKWebResponse.Current.Items.ExecuteJSCode(Format(
      'showErrorMessage({title: "%s", msg: %s});'
      , [_('Error'), TJS.StrToJS(AMessage, True)]))
  else
    TKWebResponse.Current.Items.AddHTML(TNetEncoding.HTML.Encode(AMessage).Replace(sLineBreak, '<br/>'));
end;

procedure TKWebApplication.MethodCallError(const AMessage, AMethodName, AParams: string);
var
  LMessage: string;
begin
  {$IFDEF DEBUG}
    LMessage := AMessage +
      sLineBreak + 'Method: ' + IfThen(AMethodName = '', 'Home', AMethodName)
      + IfThen(AParams = '', '', sLineBreak + 'Params:' + sLineBreak + AnsiReplaceStr(AParams, '&', sLineBreak));
  {$ELSE}
    LMessage := AMessage;
  {$ENDIF}
  Error(LMessage);
end;

procedure TKWebApplication.MethodNotFoundError(const AMethodName: string);
begin
  Error(Format('Method: ''%s'' not found', [AMethodName]));
end;

function TKWebApplication.GetLibraryTags: string;
var
  LResult: string;

  procedure AddReference(const APathName: string; const AIsRequired: Boolean = False);
  var
    LURL: string;
    LLocalPathName: string;
  begin
    LLocalPathName := APathName.Replace('/', PathDelim);
    if AIsRequired then
      LURL := GetResourceURL(LLocalPathName)
    else
      LURL := FindResourceURL(LLocalPathName);
    if LURL <> '' then
    begin
      if LURL.EndsWith('.js', True) then
        LResult := LResult + '<script src="' + LURL + '"></script>' + sLineBreak
      else
        LResult := LResult + '<link rel="stylesheet" href="' + LURL + '" />' + sLineBreak;
    end;
  end;

var
  LRef: string;
begin
  LResult := '';
{ TODO :
Find a way to reference optional libraries only if the controllers that need
them are linked in; maybe a global repository fed by initialization sections.
Duplicates must be handled/ignored. }
  AddReference('ext/build/packages/ux/classic/ux'{$IFDEF DebugExtJS} + '-debug'{$ENDIF} + '.js', True);
  AddReference('ext/build/packages/ux/classic/' + FTheme + '/resources/ux-all'{$IFDEF DebugExtJS} + '-debug'{$ENDIF} + '.css');
  AddReference('ext/build/packages/charts/classic/charts'{$IFDEF DebugExtJS} + '-debug'{$ENDIF} + '.js', True);
  AddReference('ext/build/packages/charts/classic/' + FTheme + '/resources/charts-all'{$IFDEF DebugExtJS} + '-debug'{$ENDIF} + '.css');
  AddReference('js/DateTimeField.js', True);

  AddReference('js/kitto-core.js', True);
  AddReference('js/kitto-core.css', True);
  if TKWebRequest.Current.IsMobileBrowser then
  begin
    AddReference('js/kitto-core-mobile.js', True);
    AddReference('js/kitto-core-mobile.css', True);
  end
  else
  begin
    AddReference('js/kitto-core-desktop.js', True);
    AddReference('js/kitto-core-desktop.css', True);
  end;
  AddReference('js/kitto-init.js', True);
  AddReference('js/application.js');
  AddReference('js/application.css');

  for LRef in FAdditionalRefs do
    AddReference(LRef, True);

  for LRef in Config.Config.GetStringArray('JavaScriptLibraries') do
    AddReference(LRef, True);

  Result := LResult;
end;

function TKWebApplication.GetAccessController: TKAccessController;
var
  LType: string;
  LConfig: TEFNode;
  I: Integer;
begin
  if not Assigned(FAccessController) then
  begin
    LType := Config.Config.GetExpandedString('AccessControl', NODE_NULL_VALUE);
    FAccessController := TKAccessControllerFactory.Instance.CreateObject(LType);
    LConfig := Config.Config.FindNode('AccessControl');
    if Assigned(LConfig) then
    begin
      for I := 0 to LConfig.ChildCount - 1 do
        FAccessController.Config.AddChild(TEFNode.Clone(LConfig.Children[I]));
      FAccessController.Init;
    end;
  end;
  Result := FAccessController;
end;

function TKWebApplication.GetAuthenticator: TKAuthenticator;
var
  LType: string;
  LConfig: TEFNode;
  I: Integer;
begin
  if not Assigned(FAuthenticator) then
  begin
    LType := Config.Config.GetExpandedString('Auth', NODE_NULL_VALUE);
    FAuthenticator := TKAuthenticatorFactory.Instance.CreateObject(LType);
    LConfig := Config.Config.FindNode('Auth');
    if Assigned(LConfig) then
      for I := 0 to LConfig.ChildCount - 1 do
        FAuthenticator.Config.AddChild(TEFNode.Clone(LConfig.Children[I]));
  end;
  Result := FAuthenticator;
end;

class function TKWebApplication.GetCurrent: TKWebApplication;
begin
  Result := FCurrent;
end;

function TKWebApplication.GetCustomJS: string;
begin
  Result :=
    'function setViewportWidth(w) {' + sLineBreak +
    '  var defWidth = ' + IntToStr(DEFAULT_VIEWPORT_WIDTH) + ';' + sLineBreak +
    '  var mvp = document.getElementById("viewport");' + sLineBreak +
    '  if (w != defWidth)' + sLineBreak +
    '    mvp.setAttribute("content", "' + ReplaceStr(Session.ViewportContent, '{width}', '" + w + "') + '");' + sLineBreak +
    '}';
end;

function TKWebApplication.GetViewportContent: string;
begin
  Result := ReplaceStr(Session.ViewportContent, '{width}', IntToStr(DEFAULT_VIEWPORT_WIDTH));
end;

procedure TKWebApplication.SetViewportContent;
var
  LPair: TEFPair;
  LPairs: TEFPairs;

  function GetSeparator: string;
  begin
    // IE on Windows Phone wants comma, others want space.
    if string(TKWebRequest.Current.UserAgent).Contains('Windows Phone') then
      Result := ', '
    else
      Result := ' ';
  end;

begin
  Session.ViewportContent := '';
  SetLength(LPairs, 2);
  LPairs[0] := TEFPair.Create('width', '{width}');
  LPairs[1] := TEFPair.Create('user-scalable', '0');
  LPairs := GetHomeView(Session.ViewportWidthInInches).GetChildrenAsPairs('MobileSettings/ViewportContent', True, LPairs);
  for LPair in LPairs do
  begin
    if Session.ViewportContent = '' then
      Session.ViewportContent := LPair.Key + '=' + LPair.Value
    else
      Session.ViewportContent := Session.ViewportContent + GetSeparator + LPair.Key + '=' + LPair.Value;
  end;
end;

function TKWebApplication.TooltipsEnabled: Boolean;
begin
  Result := not TKWebRequest.Current.IsMobileBrowser;
end;

procedure TKWebApplication.UpdateObserver(const ASubject: IEFSubject; const AContext: string);
begin
  inherited;
  if (ASubject.AsObject = Session.LoginController.AsObject) and SameText(AContext, 'LoggedIn') then
    ReloadOrDisplayHomeView;
end;

procedure TKWebApplication.ServeHomePage;
var
  LHtml: string;
begin
  LHtml := GetMainPageTemplate;
  // Replace template macros in main page code.
  LHtml := ReplaceText(LHtml, '<%HTMLDeclaration%>', '<?xml version=1.0?>' + sLineBreak +
    '<!doctype html public "-//W3C//DTD XHTML 1.0 Strict//EN">' + sLineBreak +
    '<html xmlns=http://www.w3org/1999/xthml>' + sLineBreak);
  LHtml := ReplaceText(LHtml, '<%ViewportContent%>', GetViewportContent);
  LHtml := ReplaceText(LHtml, '<%ApplicationTitle%>', Config.AppTitle);
  LHtml := ReplaceText(LHtml, '<%ApplicationIconLink%>',
    IfThen(Config.AppIcon = '', '', '<link rel="shortcut icon" href="' + GetImageURL(Config.AppIcon) + '"/>'));
  LHtml := ReplaceText(LHtml, '<%AppleIconLink%>',
    IfThen(Config.AppIcon = '', '', '<link rel="apple-touch-icon" sizes="120x120" href="' + GetImageURL(Config.AppIcon) + '"/>'));
  LHtml := ReplaceText(LHtml, '<%CharSet%>', TKWebResponse.Current.Items.Charset);
  LHtml := ReplaceText(LHtml, '<%ExtJSPath%>', FExtJSPath);
  LHtml := ReplaceText(LHtml, '<%ResourcePath%>', FResourcePath);
  LHtml := ReplaceText(LHtml, '<%ManifestLink%>', IfThen(GetManifestFileName = '', '',
    Format('<link rel="manifest" href="%s"/>', [GetManifestFileName])));
  LHtml := ReplaceText(LHtml, '<%ThemeLink%>',
    IfThen(Theme = '', '', '<link rel=stylesheet href="' + FExtJSPath + '/build/classic/theme-' + Theme +
      '/resources/theme-' + Theme + '-all.css" />'));
  LHtml := ReplaceText(LHtml, '<%LanguageLink%>',
    IfThen((Session.Language = 'en') or (Session.Language = ''), '',
      '<script src="' + FExtJSPath + '/build/classic/locale/locale-' + Session.Language + '.js"></script>'));
  LHtml := ReplaceText(LHtml, '<%LibraryTags%>', GetLibraryTags);
  LHtml := ReplaceText(LHtml, '<%CustomJS%>', GetCustomJS);
  LHtml := ReplaceText(LHtml, '<%Response%>', TKWebResponse.Current.Items.Consume);

  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(LHtml);
end;

function TKWebApplication.GetMainPageTemplate: string;
begin
  Result := GetPageTemplate('index');
end;

function TKWebApplication.GetManifestFileName: string;
var
  LManifestFile, LURL: string;
begin
  LManifestFile := GetHomeView(Session.ViewportWidthInInches).GetString('MobileSettings/Android/Manifest', 'Manifest.json');
  LURL := FindResourceURL(LManifestFile);
  if LURL <> '' then
    Result := LURL
  else
    Result := '';
end;

function TKWebApplication.FindPageTemplate(const APageName: string): string;
var
  LFileName: string;
begin
  LFileName := FindResourcePathName(APageName + '.html');
  if LFileName <> '' then
  begin
    Result := TextFileToString(LFileName, TKWebResponse.Current.Items.Encoding);
    Result := TEFMacroExpansionEngine.Instance.Expand(Result);
  end;
end;

procedure TKWebApplication.Toast(const AMessage: string);
begin
  TKWebResponse.Current.Items.ExecuteJSCode('Ext.toast(' + TJS.StrToJS(AMessage) + ');');
end;

procedure TKWebApplication.Navigate(const AURL: string);
begin
  TKWebResponse.Current.Items.ExecuteJSCode(Format('window.open("%s", "_blank");', [AURL]));
end;

function TKWebApplication.GetPageTemplate(const APageName: string): string;
begin
  Result := FindPageTemplate(APageName);
  if Result = '' then
    raise Exception.CreateFmt('Template not found for page %s', [APageName]);
end;

procedure TKWebApplication.Logout;
begin
  GetAuthenticator.Logout;
  Reload;
end;

procedure TKWebApplication.Reload;
begin
  // Ajax calls are useless since we're reloading, so let's make sure
  // the response doesn't contain any.
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.ExecuteJSCode('window.location.reload();');
end;

function TKWebApplication.FindResourcePathName(const AResourceFileName: string): string;
begin
  Result := TPath.Combine(Config.AppHomePath, 'Resources') + PathDelim + StripPrefix(AResourceFileName, PathDelim);
  if not FileExists(Result) then
    Result := TPath.Combine(Config.SystemHomePath, 'Resources') + PathDelim + StripPrefix(AResourceFileName, PathDelim);
  if not FileExists(Result) then
    Result := '';
end;

function TKWebApplication.GetResourcePathName(const AResourceFileName: string): string;
begin
  Result := FindResourcePathName(AResourceFileName);
  if Result = '' then
    raise EKError.CreateFmt(_('Resource %s not found.'), [AResourceFileName]);
end;

function TKWebApplication.FindResourceURL(const AResourceFileName: string): string;
begin
  if FindResourcePathName(AResourceFileName) = '' then
    // File not found: no URL.
    Result := ''
  else
    Result := FResourcePath + '/' + StripPrefix(AResourceFileName, PathDelim).Replace(PathDelim, '/');
end;

function TKWebApplication.GetResourceURL(const AResourceFileName: string): string;
begin
  Result := FindResourceURL(AResourceFileName);
  if Result = '' then
    raise EKError.CreateFmt(_('Resource %s not found.'), [AResourceFileName]);
end;

function TKWebApplication.GetImagePathName(const AResourceName, ASuffix: string): string;
begin
  Result := GetResourcePathName(AdaptImageName(AResourceName, ASuffix));
end;

function TKWebApplication.GetImageURL(const AResourceName: string; const ASuffix: string = ''): string;
begin
  Result := GetResourceURL(AdaptImageName(AResourceName, ASuffix));
end;

function TKWebApplication.FindImagePathName(const AResourceName: string; const ASuffix: string = ''): string;
begin
  Result := FindResourcePathName(AdaptImageName(AResourceName, ASuffix));
end;

function TKWebApplication.FindImageURL(const AResourceName, ASuffix: string): string;
begin
  Result := FindResourceURL(AdaptImageName(AResourceName, ASuffix));
end;

class function TKWebApplication.AdaptImageName(const AResourceName: string; const ASuffix: string = ''): string;

  function HasSize(const AName: string): Boolean;
  begin
    Result := EndsStr('_16', AName) or EndsStr('_24', AName)
      or EndsStr('_32', AName) or EndsStr('_48', AName);
  end;

begin
  Result := AResourceName;
  if HasSize(Result) then
    Insert(ASuffix, Result, Length(Result) - 2)
  else
    Result := Result + ASuffix;
  Result := Result + '.png';
end;

end.
