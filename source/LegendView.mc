import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class LegendView extends WatchUi.View {

    private var _icons  as Array;
    private var _labels as Array;

    function initialize() {
        View.initialize();
        _labels = [
            "Intensitat de pluja",
            "Acumulació de pluja",
            "Tempestes",
            "Vent violent",
            "Allaus",
            "Acumulació de neu",
            "Temperatures"
        ];
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

        var w  = dc.getWidth();
        var cx = w / 2;

        // Header — white band full width
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, w, 34);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.drawText(cx, 10, Graphics.FONT_XTINY, "Llegenda", Graphics.TEXT_JUSTIFY_CENTER);

        // One row per alert type: icon at x=65, label at x=87
        var y = 50;
        var rowH = 26;
        for (var t = 0; t < 7; t++) {
            dc.drawBitmap(65, y + 2, _icons[t] as WatchUi.BitmapResource);
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(87, y - 2, Graphics.FONT_XTINY, _labels[t] as String,
                        Graphics.TEXT_JUSTIFY_LEFT);
            y += rowH;
        }
    }
}
