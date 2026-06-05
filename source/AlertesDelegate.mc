import Toybox.Lang;
import Toybox.WatchUi;

class AlertesDelegate extends WatchUi.BehaviorDelegate {

    private var _view as AlertesAndorraView;

    function initialize(view as AlertesAndorraView) {
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
        _view.openDetail();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
