import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class AlertesAndorraApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new AlertesAndorraView();
        return [view, new AlertesDelegate(view)];
    }
}

function getApp() as AlertesAndorraApp {
    return Application.getApp() as AlertesAndorraApp;
}
