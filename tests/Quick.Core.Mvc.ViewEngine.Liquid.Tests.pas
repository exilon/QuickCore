unit Quick.Core.Mvc.ViewEngine.Liquid.Tests;

(* Tests: T-VE-01..25
    T-VE-01  Variable output resolved from ViewData
    T-VE-02  Variable output resolved from ViewModel via RTTI
    T-VE-03  Filter upcase, downcase, capitalize
    T-VE-04  Filter default replaces empty string
    T-VE-05  Filter truncate shortens long strings
    T-VE-06  Filter escape HTML-encodes special chars
    T-VE-07  if branch renders true-branch; false-branch empty
    T-VE-08  unless is inverse of if
    T-VE-09  if with == comparison operator
    T-VE-10  for iterates comma-separated collection
    T-VE-11  Custom registered filter is applied
    T-VE-12  assign stores variable for later use
    T-VE-13  Built-in now / today variables are non-empty
    T-VE-14  Filter chain: multiple filters piped together
    T-VE-15  if...else...endif else branch
    T-VE-16  Filter append suffix
    T-VE-17  Filter prepend prefix
    T-VE-18  Filter replace old with new
    T-VE-19  Filter size returns string length
    T-VE-20  forloop.index0 is 0-based
    T-VE-21  forloop.first / forloop.last flags
    T-VE-22  if with != operator
    T-VE-23  if with numeric > comparison
    T-VE-24  ViewModel Double property resolved via RTTI
    T-VE-25  Empty collection in for produces no output
*)

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Quick.Value,
  Quick.Core.Mvc.ViewFeatures,
  Quick.Core.Mvc.ViewEngine.Liquid;

type

  { Simple ViewModel for RTTI tests }
  {$M+}
  TLiquidTestProduct = class
  private
    fName  : string;
    fPrice : Double;
    fStock : Integer;
  published
    property Name  : string  read fName  write fName;
    property Price : Double  read fPrice write fPrice;
    property Stock : Integer read fStock write fStock;
  end;
  {$M-}

  [TestFixture]
  TLiquidViewTests = class
  private
    // Helper: run the Liquid rendering pipeline without a real HTTP context.
    function Render(const aTemplate : string;
                    aViewData : TViewDataDictionary;
                    aModel    : TObject) : string;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test] procedure T_VE_01_Variable_From_ViewData;
    [Test] procedure T_VE_02_Variable_From_ViewModel;
    [Test] procedure T_VE_03_Filters_Case;
    [Test] procedure T_VE_04_Filter_Default_Replaces_Empty;
    [Test] procedure T_VE_05_Filter_Truncate;
    [Test] procedure T_VE_06_Filter_Escape_HTML;
    [Test] procedure T_VE_07_If_True_Branch;
    [Test] procedure T_VE_08_Unless_Is_Inverse;
    [Test] procedure T_VE_09_If_Equality_Operator;
    [Test] procedure T_VE_10_For_Loop_Iterates_Collection;
    [Test] procedure T_VE_11_Custom_Registered_Filter;
    [Test] procedure T_VE_12_Assign_Tag_Stores_Variable;
    [Test] procedure T_VE_13_Builtin_Now_Today_NonEmpty;
    [Test] procedure T_VE_14_Filter_Chain;
    [Test] procedure T_VE_15_If_Else_Branch;
    [Test] procedure T_VE_16_Filter_Append;
    [Test] procedure T_VE_17_Filter_Prepend;
    [Test] procedure T_VE_18_Filter_Replace;
    [Test] procedure T_VE_19_Filter_Size;
    [Test] procedure T_VE_20_ForLoop_Index0;
    [Test] procedure T_VE_21_ForLoop_First_Last;
    [Test] procedure T_VE_22_If_NotEqual_Operator;
    [Test] procedure T_VE_23_If_Numeric_Comparison;
    [Test] procedure T_VE_24_ViewModel_Double_Property;
    [Test] procedure T_VE_25_For_Empty_Collection_No_Output;
  end;

implementation

uses
  System.RegularExpressions,
  System.IOUtils,
  System.Classes;

// ─── TTestLiquidEngine — full-pipeline test helper ───────────────────────────
//
// Writes the template to a temp file, creates a bare TActionContext (nil http
// context — never dereferenced during pure rendering), pairs it with a
// MemoryStream-backed TViewContext, and returns the rendered string.

type
  TTestLiquidEngine = class
  public
    class function Process(const aTemplate: string;
                           aViewData : TViewDataDictionary;
                           aModel    : TObject) : string;
  end;

const
  TEMP_DIR = '.\__liquid_test_tmp\';

class function TTestLiquidEngine.Process(const aTemplate: string;
                                         aViewData : TViewDataDictionary;
                                         aModel    : TObject) : string;
var
  tmpFile : string;
  ms      : TMemoryStream;
  view    : TLiquidView;
  actCtx  : TActionContext;
  viewCtx : TViewContext;
begin
  if not TDirectory.Exists(TEMP_DIR) then TDirectory.CreateDirectory(TEMP_DIR);
  tmpFile := TPath.Combine(TEMP_DIR, 'test_' + GUIDToString(TGuid.NewGuid) + '.liquid');
  TFile.WriteAllText(tmpFile, aTemplate, TEncoding.UTF8);
  try
    ms := TMemoryStream.Create;
    try
      // TActionContext is NOT abstract; passing nil for HttpContext/RouteData
      // is safe because TLiquidView only touches ViewData and ViewModel.
      actCtx  := TActionContext.Create(nil, nil);
      viewCtx := TViewContext.Create(actCtx, aViewData, aModel, ms);
      try
        view := TLiquidView.Create(tmpFile);
        try
          view.Render(viewCtx);
        finally
          view.Free;
        end;
        ms.Position := 0;
        with TStreamReader.Create(ms, TEncoding.UTF8) do
        try
          Result := ReadToEnd;
        finally
          Free;
        end;
      finally
        viewCtx.Free;
        actCtx.Free;
      end;
    finally
      ms.Free;
    end;
  finally
    if TFile.Exists(tmpFile) then TFile.Delete(tmpFile);
  end;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TLiquidViewTests
// ─────────────────────────────────────────────────────────────────────────────

procedure TLiquidViewTests.SetUp;
begin
  // nothing
end;

procedure TLiquidViewTests.TearDown;
begin
  // nothing
end;

function TLiquidViewTests.Render(const aTemplate : string;
                                  aViewData       : TViewDataDictionary;
                                  aModel          : TObject) : string;
begin
  Result := TTestLiquidEngine.Process(aTemplate, aViewData, aModel);
end;

// ─── T-VE-01: ViewData variable ───────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_01_Variable_From_ViewData;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['title'] := 'QuickCore';
    out := Render('Hello {{ viewdata.title }}!', vd, nil);
    Assert.AreEqual('Hello QuickCore!', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-02: ViewModel property ─────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_02_Variable_From_ViewModel;
var
  m   : TLiquidTestProduct;
  vd  : TViewDataDictionary;
  out : string;
begin
  m := TLiquidTestProduct.Create;
  vd := TViewDataDictionary.Create;
  try
    m.Name := 'Laptop';
    out := Render('Product: {{ model.Name }}', vd, m);
    Assert.AreEqual('Product: Laptop', Trim(out));
  finally
    m.Free;
    vd.Free;
  end;
end;

// ─── T-VE-03: upcase / downcase / capitalize ─────────────────────────────────

procedure TLiquidViewTests.T_VE_03_Filters_Case;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['word'] := 'hello';
    out := Render('{{ viewdata.word | upcase }}', vd, nil);
    Assert.AreEqual('HELLO', Trim(out), 'upcase');
    out := Render('{{ viewdata.word | capitalize }}', vd, nil);
    Assert.AreEqual('Hello', Trim(out), 'capitalize');
    vd['word2'] := 'WORLD';
    out := Render('{{ viewdata.word2 | downcase }}', vd, nil);
    Assert.AreEqual('world', Trim(out), 'downcase');
  finally
    vd.Free;
  end;
end;

// ─── T-VE-04: default filter ─────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_04_Filter_Default_Replaces_Empty;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['empty'] := '';
    out := Render('{{ viewdata.empty | default: ''N/A'' }}', vd, nil);
    Assert.AreEqual('N/A', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-05: truncate filter ────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_05_Filter_Truncate;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['long'] := 'The quick brown fox';
    out := Render('{{ viewdata.long | truncate: 10 }}', vd, nil);
    Assert.AreEqual('The quick ...', Trim(out));  // Copy(s,1,10)='The quick ' + '...'
  finally
    vd.Free;
  end;
end;

// ─── T-VE-06: escape filter ──────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_06_Filter_Escape_HTML;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['html'] := '<b>Alert & "danger"</b>';
    out := Render('{{ viewdata.html | escape }}', vd, nil);
    Assert.AreEqual('&lt;b&gt;Alert &amp; &quot;danger&quot;&lt;/b&gt;', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-07: if true branch ─────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_07_If_True_Branch;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['visible'] := 'true';
    out := Render('{% if viewdata.visible %}YES{% endif %}', vd, nil);
    Assert.AreEqual('YES', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-08: unless is inverse of if ────────────────────────────────────────

procedure TLiquidViewTests.T_VE_08_Unless_Is_Inverse;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['hidden'] := '';
    out := Render('{% unless viewdata.hidden %}SHOWN{% endunless %}', vd, nil);
    Assert.AreEqual('SHOWN', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-09: if with == operator ────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_09_If_Equality_Operator;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['role'] := 'Admin';
    out := Render('{% if viewdata.role == "Admin" %}ADMIN{% endif %}', vd, nil);
    Assert.AreEqual('ADMIN', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-10: for loop ───────────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_10_For_Loop_Iterates_Collection;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['items'] := 'Apple,Banana,Cherry';
    out := Render('{% for fruit in viewdata.items %}{{ fruit }} {% endfor %}', vd, nil);
    // Each iteration produces "<item> " → concatenated: "Apple Banana Cherry "
    Assert.AreEqual('Apple Banana Cherry', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-11: custom registered filter ───────────────────────────────────────

procedure TLiquidViewTests.T_VE_11_Custom_Registered_Filter;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  TLiquidView.RegisterFilter('money',
    function(const v, _ : string) : string
    begin Result := '$' + v; end);
  vd := TViewDataDictionary.Create;
  try
    vd['price'] := '9.99';
    out := Render('{{ viewdata.price | money }}', vd, nil);
    Assert.AreEqual('$9.99', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-12: assign tag ─────────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_12_Assign_Tag_Stores_Variable;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    out := Render('{% assign greeting = "Hi" %}{{ greeting }}', vd, nil);
    Assert.AreEqual('Hi', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-13: built-in now / today ───────────────────────────────────────────

procedure TLiquidViewTests.T_VE_13_Builtin_Now_Today_NonEmpty;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    out := Render('{{ today }}', vd, nil);
    Assert.IsNotEmpty(Trim(out), 'today should not be empty');
    out := Render('{{ now }}', vd, nil);
    Assert.IsNotEmpty(Trim(out), 'now should not be empty');
  finally
    vd.Free;
  end;
end;

// ─── T-VE-14: filter chain ───────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_14_Filter_Chain;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['msg'] := '  hello world  ';
    out := Render('{{ viewdata.msg | strip | upcase }}', vd, nil);
    Assert.AreEqual('HELLO WORLD', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-15: if...else...endif ──────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_15_If_Else_Branch;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['logged_in'] := '';
    out := Render('{% if viewdata.logged_in %}Welcome back!{% else %}Please sign in{% endif %}', vd, nil);
    Assert.AreEqual('Please sign in', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-16: | append filter ────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_16_Filter_Append;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['base'] := 'item';
    out := Render('{{ viewdata.base | append: ''s'' }}', vd, nil);
    Assert.AreEqual('items', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-17: | prepend filter ───────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_17_Filter_Prepend;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['price'] := '9.99';
    out := Render('{{ viewdata.price | prepend: ''$'' }}', vd, nil);
    Assert.AreEqual('$9.99', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-18: | replace filter ───────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_18_Filter_Replace;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['txt'] := 'Hello World';
    out := Render('{{ viewdata.txt | replace: ''World, Delphi'' }}', vd, nil);
    Assert.AreEqual('Hello Delphi', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-19: | size filter ──────────────────────────────────────────────────

procedure TLiquidViewTests.T_VE_19_Filter_Size;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['word'] := 'Hello';
    out := Render('{{ viewdata.word | size }}', vd, nil);
    Assert.AreEqual('5', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-20: forloop.index0 (0-based) ───────────────────────────────────────

procedure TLiquidViewTests.T_VE_20_ForLoop_Index0;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['items'] := 'A,B,C';
    // forloop.index0 should be 0,1,2
    out := Render('{% for x in viewdata.items %}{{ forloop.index0 }}{% endfor %}', vd, nil);
    Assert.AreEqual('012', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-21: forloop.first / forloop.last ───────────────────────────────────

procedure TLiquidViewTests.T_VE_21_ForLoop_First_Last;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['items'] := 'A,B,C';
    out := Render('{% for x in viewdata.items %}{{ forloop.first }}{{ forloop.last }}{% endfor %}', vd, nil);
    // first item: first=true  last=false → 'truefalse'
    // middle:     first=false last=false → 'falsefalse'
    // last item:  first=false last=true  → 'falsetrue'
    Assert.AreEqual('truefalsefalsefalsefalsetrue', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-22: {% if %} with != operator ──────────────────────────────────────

procedure TLiquidViewTests.T_VE_22_If_NotEqual_Operator;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['status'] := 'pending';
    out := Render('{% if viewdata.status != "done" %}NOT DONE{% endif %}', vd, nil);
    Assert.AreEqual('NOT DONE', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-23: {% if %} with numeric > comparison ─────────────────────────────

procedure TLiquidViewTests.T_VE_23_If_Numeric_Comparison;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['qty'] := '10';
    out := Render('{% if viewdata.qty > 5 %}PLENTY{% endif %}', vd, nil);
    Assert.AreEqual('PLENTY', Trim(out));
  finally
    vd.Free;
  end;
end;

// ─── T-VE-24: ViewModel Double property via RTTI ─────────────────────────────

procedure TLiquidViewTests.T_VE_24_ViewModel_Double_Property;
var
  m   : TLiquidTestProduct;
  vd  : TViewDataDictionary;
  out : string;
begin
  m  := TLiquidTestProduct.Create;
  vd := TViewDataDictionary.Create;
  try
    m.Price := 49.95;
    out := Render('Price: {{ model.Price }}', vd, m);
    // TValue.ToString for Double gives locale-dependent decimal separator;
    // just verify the numeric part appears in the output.
    Assert.IsTrue(out.Contains('49'), 'Price should contain 49');
  finally
    m.Free;
    vd.Free;
  end;
end;

// ─── T-VE-25: empty collection in {% for %} produces no output ───────────────

procedure TLiquidViewTests.T_VE_25_For_Empty_Collection_No_Output;
var
  vd  : TViewDataDictionary;
  out : string;
begin
  vd := TViewDataDictionary.Create;
  try
    vd['items'] := '';   // empty → should iterate zero times
    out := Render('BEFORE{% for x in viewdata.items %}ITEM{% endfor %}AFTER', vd, nil);
    Assert.AreEqual('BEFOREAFTER', Trim(out));
  finally
    vd.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLiquidViewTests);

end.
