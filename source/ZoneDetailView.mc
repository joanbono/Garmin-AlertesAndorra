import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class ZoneDetailView extends WatchUi.View {

    private var _zone     as ZoneData;
    private var _name     as String;
    private var _icons    as Array;
    private var _scrollY  as Number;
    private var _contentH as Number;
    private var _screenH  as Number;

    function initialize(zone as ZoneData, name as String) {
        View.initialize();
        _zone     = zone;
        _name     = name;
        _scrollY  = 0;
        _contentH = 260;
        _screenH  = 260;
        _icons = [
            Application.loadResource(Rez.Drawables.icon_type1) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type2) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type3) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type4) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type5) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type6) as WatchUi.BitmapResource,
            Application.loadResource(Rez.Drawables.icon_type7) as WatchUi.BitmapResource
        ];
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        drawDetail(dc, dc.getWidth(), dc.getHeight());
    }

    // -----------------------------------------------------------------------
    // Public scroll API called by ZoneDetailDelegate
    // -----------------------------------------------------------------------

    function scrollDown() as Void {
        var maxScroll = _contentH - (_screenH - 34);
        if (maxScroll < 0) { maxScroll = 0; }
        _scrollY += 30;
        if (_scrollY > maxScroll) { _scrollY = maxScroll; }
        WatchUi.requestUpdate();
    }

    function scrollUp() as Void {
        _scrollY -= 30;
        if (_scrollY < 0) { _scrollY = 0; }
        WatchUi.requestUpdate();
    }

    // -----------------------------------------------------------------------

    private function sep(dc as Dc, y as Number, w as Number) as Void {
        dc.setColor(0x2E2E2E, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(30, y, w - 30, y);
    }

    private function buildRanges(typeIdx as Number, fromIdx as Number, toIdx as Number) as Array {
        var ranges = [];
        var ts = _zone.typeSlots[typeIdx] as Array;
        var i = fromIdx;
        while (i < toIdx) {
            var sev = ts[i] as Number;
            if (sev == 0) { i++; continue; }
            var startH = (15 + i * 3) % 24;
            var j = i + 1;
            while (j < toIdx && (ts[j] as Number) == sev) { j++; }
            var endH = (15 + j * 3) % 24;
            if (endH == 0) { endH = 24; }
            ranges.add([startH, endH, sev]);
            i = j;
        }
        return ranges;
    }

    private function drawPills(dc as Dc, ranges as Array,
                               w as Number, y as Number, startX as Number) as Number {
        var pillH = 20;
        var gap   = 4;
        var x     = startX;
        for (var k = 0; k < ranges.size(); k++) {
            var r    = ranges[k] as Array;
            var sv   = r[2] as Number;
            var text = (r[0] as Number).toString() + "-" + (r[1] as Number).toString() + "h";
            var pillW = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY) + 14;
            if (x + pillW > w - 20) {
                x = startX;
                y += pillH + gap;
            }
            dc.setColor(alertColor(sv), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, pillW, pillH, 4);
            dc.setColor(sv == 1 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + pillW / 2, y + 0, Graphics.FONT_XTINY, text,
                        Graphics.TEXT_JUSTIFY_CENTER);
            x += pillW + gap;
        }
        return y + pillH + gap;
    }

    private function drawSection(dc as Dc, w as Number, y as Number,
                                 fromIdx as Number, toIdx as Number) as Number {
        var hasAlerts = false;
        for (var t = 0; t < 7; t++) {
            var ranges = buildRanges(t, fromIdx, toIdx);
            if (ranges.size() == 0) { continue; }
            hasAlerts = true;
            dc.drawBitmap(30, y + 2, _icons[t] as WatchUi.BitmapResource);
            y = drawPills(dc, ranges, w, y, 50);
        }
        if (!hasAlerts) {
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(30, y, Graphics.FONT_XTINY, "Cap avís", Graphics.TEXT_JUSTIFY_LEFT);
            y += 24;
        }
        return y;
    }

    private function drawDetail(dc as Dc, w as Number, h as Number) as Void {
        _screenH = h;
        var cx = w / 2;

        // ── Fixed header ────────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, 34);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(cx, 12, Graphics.FONT_XTINY, _name, Graphics.TEXT_JUSTIFY_CENTER);

        // ── Scrollable content (clipped below header) ───────────────────────
        dc.setClip(0, 34, w, h - 34);

        var base = 48 - _scrollY;

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(30, base, Graphics.FONT_XTINY, "Avui", Graphics.TEXT_JUSTIFY_LEFT);
        var y = drawSection(dc, w, base + 26, 0, 3);

        y += 6;
        sep(dc, y, w);
        y += 12;

        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(30, y, Graphics.FONT_XTINY, "Demà", Graphics.TEXT_JUSTIFY_LEFT);
        y += 22;
        y = drawSection(dc, w, y, 3, 11);

        _contentH = y - 34 + _scrollY + 10;

        dc.clearClip();

        // ── Fixed footer ────────────────────────────────────────────────────
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 12, Graphics.FONT_XTINY, "* Llegenda",
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Scroll indicator: thin bar on right edge, only when content overflows
        var visibleH = h - 34;
        if (_contentH > visibleH) {
            var trackH = visibleH - 20;
            var thumbH = (trackH * visibleH) / _contentH;
            if (thumbH < 6) { thumbH = 6; }
            var maxScroll = _contentH - visibleH;
            var thumbY = 34 + 10 + (_scrollY * (trackH - thumbH)) / maxScroll;
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w - 4, 44, 2, trackH);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w - 4, thumbY, 2, thumbH);
        }
    }
}
