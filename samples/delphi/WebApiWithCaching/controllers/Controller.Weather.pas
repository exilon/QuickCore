unit Controller.Weather;

{ WebApiWithCaching Sample - S-09
  Demonstrates the cache-aside pattern with IMemoryCache. }

interface

uses
  Quick.Core.Mvc.Controller,
  Quick.Core.Mvc.ActionResult,
  Quick.Core.Caching.Abstractions,
  Quick.Core.Logging.Abstractions;

type
  [Route('api/weather')]
  [ApiController]
  TWeatherController = class(THttpController)
  private
    const CACHE_KEY = 'WeatherData';
    var
      fCache  : IMemoryCache;
      fLogger : ILogger;
  public
    constructor Create(aCache : IMemoryCache; aLogger : ILogger);
  published
    [HttpGet]
    function GetWeather : IActionResult;

    [HttpDelete('cache')]
    function ClearCache : IActionResult;
  end;

implementation

uses
  System.SysUtils;

{ TWeatherController }

constructor TWeatherController.Create(aCache : IMemoryCache; aLogger : ILogger);
begin
  inherited Create;
  fCache  := aCache;
  fLogger := aLogger;
end;

function TWeatherController.GetWeather: IActionResult;
var
  data : string;
begin
  if fCache.TryGetValue(CACHE_KEY, data) then
  begin
    fLogger.Info('Weather data served from CACHE');
    Result := Json(Format('{"source":"cache","data":%s}', [data]));
  end
  else
  begin
    fLogger.Info('Weather data fetched from source (simulated)');
    // Simulate fetching fresh data
    data := '[{"city":"Madrid","temp":25},{"city":"London","temp":18}]';
    fCache.SetValue(CACHE_KEY, data, 30);  // cache for 30 seconds
    Result := Json(Format('{"source":"fresh","data":%s}', [data]));
  end;
end;

function TWeatherController.ClearCache: IActionResult;
begin
  fCache.RemoveValue(CACHE_KEY);
  fLogger.Info('Weather cache cleared');
  Result := Json('{"message":"Cache cleared"}');
end;

initialization
  RegisterController(TWeatherController);

end.
