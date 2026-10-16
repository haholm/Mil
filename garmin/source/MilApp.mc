using Toybox.Application;
using Toybox.Graphics;
using Toybox.WatchUi;

class MilApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as Array<WatchUi.Views or WatchUi.InputDelegates> {
        return [ new MilView() ];
    }
}

class MilView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 22,
            Graphics.FONT_MEDIUM, "Mil", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 + 10,
            Graphics.FONT_SMALL, "Ready to run", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
