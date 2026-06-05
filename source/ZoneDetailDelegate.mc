import Toybox.Lang;
import Toybox.WatchUi;

class ZoneDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _view as ZoneDetailView;

    function initialize(view as ZoneDetailView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.pushView(new LegendView(), new LegendDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
