import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Communications;

// ---------------------------------------------------------------------------
// Shared helpers (module-level so ZoneDetailView can also call them)
// ---------------------------------------------------------------------------

// Severity: 0=cap avís, 1=groc, 2=taronja, 3=vermell
function alertColor(s as Number) as Number {
    if (s == 3) { return 0xDD2222; }
    if (s == 2) { return 0xFF8C00; }
    if (s == 1) { return 0xFFDB23; }
    return 0xFFFFFF;
}

function alertLabel(s as Number) as String {
    if (s == 3) { return "Vermell"; }
    if (s == 2) { return "Taronja"; }
    if (s == 1) { return "Groc"; }
    return "Cap avís";
}

function alertType(s as Number) as String {
    if (s == 7) { return "Temp."; }   // Temperatures
    if (s == 6) { return "Neu"; }     // Acumulació de Neu
    if (s == 5) { return "Allaus"; }  // Allaus
    if (s == 4) { return "Vent"; }    // Vent violent
    if (s == 3) { return "Tempes."; } // Tempestes
    if (s == 2) { return "Pluja"; }   // Acumulació de Pluja
    if (s == 1) { return "I.Pluja"; } // Intensitat de Pluja
    return "Cap avís";
}

// ---------------------------------------------------------------------------
// ZoneData — stores parsed alert data for one geographic zone.
// 16 time slots spanning ~48 h starting from the current "Avui 15h":
//   0-2  → Avui  (15h, 18h, 21h)
//   3-10 → Demà  (0h … 21h)
//   11-15→ D+2   (0h … 12h)
// ---------------------------------------------------------------------------
class ZoneData {
    var slots     as Array;
    var typeSlots as Array;

    function initialize() {
        slots     = new [16];
        typeSlots = new [7];
        for (var i = 0; i < 16; i++) {
            slots[i] = 0;
        }
        for (var t = 0; t < 7; t++) {
            var ts = new [16];
            for (var i = 0; i < 16; i++) {
                ts[i] = 0;
            }
            typeSlots[t] = ts;
        }
    }

    function rebuildSlots() as Void {
        for (var i = 0; i < 16; i++) {
            var max = 0;
            for (var t = 0; t < 7; t++) {
                var v = ((typeSlots[t] as Array)[i]) as Number;
                if (v > max) { max = v; }
            }
            slots[i] = max;
        }
    }

    function maxSeverity() as Number {
        var max = 0;
        for (var i = 0; i < 16; i++) {
            if ((slots[i] as Number) > max) {
                max = slots[i] as Number;
            }
        }
        return max;
    }

    // Returns "15h 18h" style string for active slots in [from, to).
    // Shows up to 4 individual hours; if more, appends "+N".
    function activeHoursStr(fromIdx as Number, toIdx as Number) as String {
        var active = [];
        var end = toIdx < 16 ? toIdx : 16;
        for (var i = fromIdx; i < end; i++) {
            if ((slots[i] as Number) > 0) {
                active.add(i);
            }
        }
        if (active.size() == 0) {
            return "-";
        }
        var result = "";
        var limit = active.size() > 4 ? 4 : active.size();
        for (var j = 0; j < limit; j++) {
            var idx  = active[j] as Number;
            var hour = (15 + idx * 3) % 24;
            if (!result.equals("")) {
                result = result + " ";
            }
            result = result + hour.toString() + "h";
        }
        var extra = active.size() - limit;
        if (extra > 0) {
            result = result + "+" + extra.toString();
        }
        return result;
    }
}

// ---------------------------------------------------------------------------
// AlertesView — scrollable list of three alert zones
// ---------------------------------------------------------------------------
class AlertesAndorraView extends WatchUi.View {

    private var _nord        as ZoneData;
    private var _centre      as ZoneData;
    private var _sud         as ZoneData;
    private var _isLoading   as Boolean;
    private var _hasError    as Boolean;
    private var _errorCode   as Number;
    private var _lastUpdate  as String;
    private var _selectedIdx as Number;
    private var _icons       as Array;
    private var _tickIcon      as WatchUi.BitmapResource;
    private var _loadingSplash as WatchUi.BitmapResource;

    function initialize() {
        View.initialize();
        _nord        = new ZoneData();
        _centre      = new ZoneData();
        _sud         = new ZoneData();
        _isLoading   = true;
        _hasError    = false;
        _errorCode   = 0;
        _lastUpdate  = "--:--";
        _selectedIdx = 0;
        _icons = [
            Application.loadResource(Rez.Drawables.icon_type1) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type2) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type3) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type4) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type5) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type6) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type7) as WatchUi.BitmapResource
        ];
        _tickIcon      = Application.loadResource(Rez.Drawables.icon_tick)      as WatchUi.BitmapResource;
        _loadingSplash = Application.loadResource(Rez.Drawables.loading_splash) as WatchUi.BitmapResource;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        _isLoading = true;
        _hasError  = false;
        _errorCode = 0;
        Communications.makeWebRequest(
            "https://www.meteo.ad/Alertes",
            null,
            {
                :method       => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
            },
            method(:onReceive)
        );
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_isLoading) {
            drawLoading(dc, w, h);
        } else if (_hasError) {
            drawError(dc, w, h);
        } else {
            drawList(dc, w, h);
        }
    }

    function onHide() as Void {
    }

    // -----------------------------------------------------------------------
    // Public navigation API called by AlertesDelegate
    // -----------------------------------------------------------------------

    function scrollDown() as Void {
        _selectedIdx = (_selectedIdx + 1) % 3;
        WatchUi.requestUpdate();
    }

    function scrollUp() as Void {
        _selectedIdx = (_selectedIdx + 2) % 3;
        WatchUi.requestUpdate();
    }

    function openDetail() as Void {
        var zones = [_nord, _centre, _sud];
        var names = ["NORD", "CENTRE", "SUD"];
        var zone = zones[_selectedIdx] as ZoneData;
        var name = names[_selectedIdx] as String;
        var view = new ZoneDetailView(zone, name);
        WatchUi.pushView(view, new ZoneDetailDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // -----------------------------------------------------------------------
    // HTTP
    // -----------------------------------------------------------------------

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        _isLoading = false;
        if (responseCode == 200 && data != null) {
            parseAlerts(data.toString());
            var t = System.getClockTime();
            _lastUpdate = Lang.format("$1$:$2$", [t.hour, t.min.format("%02d")]);
        } else if (responseCode == -400 || responseCode == -300) {
            loadMockData();
        } else {
            _hasError  = true;
            _errorCode = responseCode;
        }
        WatchUi.requestUpdate();
    }

    private function loadMockData() as Void {
        // Nord – Type 0 (Intensitat de Pluja): Avui 18h taronja, 21h groc; Dema 15h taronja, 18h vermell, 21h taronja, 0h groc
        var nordT0 = _nord.typeSlots[0] as Array;
        nordT0[1] = 2; nordT0[2] = 1;
        nordT0[7] = 2; nordT0[8] = 3; nordT0[9] = 2; nordT0[10] = 1;
        // Nord – Type 2 (Tempestes): Avui 15h groc; Dema 9h groc, 12h groc
        var nordT2 = _nord.typeSlots[2] as Array;
        nordT2[0] = 1; nordT2[5] = 1; nordT2[6] = 1;
        _nord.rebuildSlots();

        // Centre – Type 3 (Vent violent): Avui 15h–18h taronja
        var centreT3 = _centre.typeSlots[3] as Array;
        centreT3[0] = 2; centreT3[1] = 2;
        // Centre – Type 4 (Allaus): Avui 15h–21h taronja (slots 0-2)
        var centreT4 = _centre.typeSlots[4] as Array;
        centreT4[0] = 2; centreT4[1] = 2; centreT4[2] = 2;
        _centre.rebuildSlots();

        // Sud – no alert
        _lastUpdate = "DEMO";
    }

    // -----------------------------------------------------------------------
    // Parsing
    // -----------------------------------------------------------------------

    private function colorToSeverity(color as String) as Number {
        var c = color.toLower();
        if (c.find("f7f7f7") >= 0) { return 0; }
        if (c.find("ffffff") >= 0) { return 0; }
        if (c.find("ffdb23") >= 0) { return 1; }
        if (c.find("ffdb")   >= 0) { return 1; }
        if (c.find("ffff00") >= 0) { return 1; }
        if (c.find("ff8c")   >= 0) { return 2; }
        if (c.find("ffa5")   >= 0) { return 2; }
        if (c.find("ff66")   >= 0) { return 2; }
        if (c.find("ff80")   >= 0) { return 2; }
        return 3;
    }

    private function parseZoneSlots(zoneHtml as String) as Array {
        var result = new [16];
        for (var i = 0; i < 16; i++) {
            result[i] = 0;
        }
        var marker    = "background-color:";
        var markerLen = marker.length();
        var section   = zoneHtml;
        var count     = 0;

        var pos = section.find(marker);
        while (pos >= 0) {
            section = section.substring(pos + markerLen, section.length());
            var endS = section.find(";");
            var endQ = section.find("'");
            var endD = section.find("\"");
            var end  = endS;
            if (end < 0 || (endQ >= 0 && endQ < end)) { end = endQ; }
            if (end < 0 || (endD >= 0 && endD < end)) { end = endD; }
            if (end > 0 && end <= 10) {
                var sev     = colorToSeverity(section.substring(0, end));
                var slotIdx = count % 16;
                if (sev > (result[slotIdx] as Number)) {
                    result[slotIdx] = sev;
                }
                count++;
            }
            pos = section.find(marker);
        }
        return result;
    }

    private function parseZoneData(zoneHtml as String, zone as ZoneData) as Void {
        var lower = zoneHtml.toLower();
        var markers = [
            "intensitat de pluja",
            "acumulació de pluja",
            "tempest",
            "vent violent",
            "allau",
            "acumulació de neu",
            "temperat"
        ];
        var positions = new [7];
        for (var t = 0; t < 7; t++) {
            positions[t] = lower.find(markers[t] as String);
        }
        for (var t = 0; t < 7; t++) {
            var start = positions[t] as Number;
            if (start < 0) { continue; }
            var end = zoneHtml.length();
            for (var u = 0; u < 7; u++) {
                if (u == t) { continue; }
                var p = positions[u] as Number;
                if (p > start && p < end) { end = p; }
            }
            zone.typeSlots[t] = parseZoneSlots(zoneHtml.substring(start, end));
        }
        zone.rebuildSlots();
    }

    private function parseAlerts(html as String) as Void {
        var nordPos   = html.find("Zona nord");
        var centrePos = html.find("Zona centre");
        var sudPos    = html.find("Zona sud");
        var jpegPos   = html.find(".jpeg");

        if (nordPos < 0 || centrePos < 0 || sudPos < 0) {
            _hasError = true;
            return;
        }
        var sudEnd = (jpegPos > sudPos) ? jpegPos : (sudPos + 6000);
        if (sudEnd > html.length()) {
            sudEnd = html.length();
        }
        parseZoneData(html.substring(nordPos,   centrePos), _nord);
        parseZoneData(html.substring(centrePos, sudPos),    _centre);
        parseZoneData(html.substring(sudPos,    sudEnd),    _sud);
    }

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    private function drawLoading(dc as Dc, w as Number, h as Number) as Void {
        dc.drawBitmap(0, 0, _loadingSplash);
    }

    private function drawError(dc as Dc, w as Number, h as Number) as Void {
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 22, Graphics.FONT_SMALL,
                    "Error", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 4, Graphics.FONT_TINY,
                    "Codi: " + _errorCode.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 26, Graphics.FONT_XTINY,
                    "Comprova connexio", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Scrollable list: three rows (Nord / Centre / Sud).
    // UP/DOWN moves selection; SELECT pushes the detail view.
    private function drawList(dc as Dc, w as Number, h as Number) as Void {
        var cx    = w / 2;
        var zones = [_nord, _centre, _sud];
        var names = ["NORD", "CENTRE", "SUD"];

        // Title — white band full width
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, w, 34);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(cx, 10, Graphics.FONT_XTINY, "Zones", Graphics.TEXT_JUSTIFY_CENTER);

        // Single-line rows centred at y = 90, 130, 170
        var rowY = [90, 130, 170];

        for (var i = 0; i < 3; i++) {
            var zone = zones[i] as ZoneData;
            var sev  = zone.maxSeverity();
            var col  = alertColor(sev);
            var sel  = (i == _selectedIdx);
            var ry   = rowY[i] as Number;
            var ty   = ry - 7;

            // Selection highlight box
            if (sel) {
                dc.setColor(0x1C1C1C, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(22, ry - 18, w - 44, 36, 8);
                dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(22, ry - 18, w - 44, 36, 8);
            }

            // Severity colour dot
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(42, ry, 6);

            // Zone name (left)
            dc.setColor(sel ? Graphics.COLOR_WHITE : 0x777777, Graphics.COLOR_TRANSPARENT);
            dc.drawText(56, ty - 9, Graphics.FONT_TINY, names[i] as String,
                        Graphics.TEXT_JUSTIFY_LEFT);

            // Active alert type icons (right-justified); tick if none active
            var iconX = w - 28;
            for (var t = 0; t < 7; t++) {
                var ts = zone.typeSlots[t] as Array;
                var active = false;
                for (var s = 0; s < 16; s++) {
                    if ((ts[s] as Number) > 0) { active = true; break; }
                }
                if (!active) { continue; }
                iconX -= 16;
                dc.drawBitmap(iconX, ry - 8, _icons[t] as WatchUi.BitmapResource);
                iconX -= 2;
            }
            if (iconX == w - 28) {
                dc.drawBitmap(w - 44, ry - 8, _tickIcon);
            }

            // Row separator (not after the last row)
            if (i < 2) {
                dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(30, ry + 20, w - 30, ry + 20);
            }
        }

        // Last-update timestamp at the bottom
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 22, Graphics.FONT_XTINY, _lastUpdate,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
