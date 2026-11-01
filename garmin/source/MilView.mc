import Toybox.Activity;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

/// A temporary diagnostic Data Field for testing live activity metrics and BLE messaging.
/// Data Fields receive Activity.Info once per second; Toybox.Sensor is unavailable here.
class MilView extends WatchUi.DataField {

    hidden var mHeartRate as Lang.Number or Null;
    hidden var mCadence as Lang.Number or Null;
    hidden var mSpeed as Lang.Float or Null;
    hidden var mPower as Lang.Number or Null;
    hidden var mAltitude as Lang.Float or Null;
    hidden var mElapsedSeconds as Lang.Numeric = 0;
    hidden var mComputeCount as Lang.Number = 0;
    hidden var mTransmitCount as Lang.Number = 0;
    hidden var mAckCount as Lang.Number = 0;
    hidden var mTransmitInFlight as Lang.Boolean = false;
    hidden var mTransmitState as Lang.String = "WAIT";
    hidden var mListener as MilTransmitListener;

    function initialize() {
        DataField.initialize();
        mHeartRate = null;
        mCadence = null;
        mSpeed = null;
        mPower = null;
        mAltitude = null;
        mListener = new MilTransmitListener(self);
        Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
    }

    function onLayout(dc as Dc) as Void {
        var obscurityFlags = DataField.getObscurityFlags();

        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.TopLeftLayout(dc));
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.TopRightLayout(dc));
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.BottomLeftLayout(dc));
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.BottomRightLayout(dc));
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));
        }
        (View.findDrawableById("label") as Text).setText("HR CAD SPD PWR ALT");
    }

    /// Garmin calls compute once per second with the native activity's current metrics.
    function compute(info as Activity.Info) as Void {
        mHeartRate = info has :currentHeartRate ? info.currentHeartRate : null;
        mCadence = info has :currentCadence ? info.currentCadence : null;
        mSpeed = info has :currentSpeed ? info.currentSpeed : null;
        mPower = info has :currentPower ? info.currentPower : null;
        mAltitude = info has :altitude ? info.altitude : null;
        mElapsedSeconds = info has :elapsedTime && info.elapsedTime != null
            ? info.elapsedTime / 1000
            : 0;
        mComputeCount += 1;

        // Low-rate probe keeps the link test gentle while still making failures visible.
        if (mComputeCount % 5 == 0 && !mTransmitInFlight) {
            sendProbe();
        }
    }

    function sendProbe() as Void {
        mTransmitInFlight = true;
        mTransmitState = "SENDING";
        var message = {
            "type" => "mil_sensor_probe",
            "sequence" => mTransmitCount + 1,
            "elapsed_seconds" => mElapsedSeconds,
            "heart_rate_bpm" => wireValue(mHeartRate),
            "cadence_spm" => wireValue(mCadence),
            "speed_mps" => wireValue(mSpeed),
            "running_power_w" => wireValue(mPower),
            "altitude_m" => wireValue(mAltitude)
        };
        try {
            Communications.transmit(message, {}, mListener);
        } catch (exception) {
            onTransmitError();
        }
    }

    function wireValue(value as Lang.Numeric or Null) as Lang.Numeric {
        return value == null ? -1 : value;
    }

    function onTransmitComplete() as Void {
        mTransmitInFlight = false;
        mTransmitCount += 1;
        mTransmitState = "SENT";
    }

    function onTransmitError() as Void {
        mTransmitInFlight = false;
        mTransmitState = "ERROR";
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        if (message.data != null) {
            mAckCount += 1;
            mTransmitState = "ACK";
        }
    }

    function onUpdate(dc as Dc) as Void {
        var label = View.findDrawableById("label") as Text;
        var value = View.findDrawableById("value") as Text;
        (View.findDrawableById("Background") as Text).setColor(getBackgroundColor());

        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            label.setColor(Graphics.COLOR_LT_GRAY);
            value.setColor(Graphics.COLOR_WHITE);
        } else {
            label.setColor(Graphics.COLOR_DK_GRAY);
            value.setColor(Graphics.COLOR_BLACK);
        }

        label.setText("HR CAD SPD PWR ALT / TX " + mTransmitState);
        value.setText(metricText(mHeartRate, mCadence, mSpeed, mPower, mAltitude));
        View.onUpdate(dc);
    }

    function metricText(
        heartRate as Lang.Number or Null,
        cadence as Lang.Number or Null,
        speed as Lang.Float or Null,
        power as Lang.Number or Null,
        altitude as Lang.Float or Null
    ) as Lang.String {
        return formatValue(heartRate, 0) + " " +
            formatValue(cadence, 0) + " " +
            formatValue(speed, 1) + " " +
            formatValue(power, 0) + " " +
            formatValue(altitude, 0) +
            "\nTX " + mTransmitCount.format("%d") +
            " ACK " + mAckCount.format("%d");
    }

    function formatValue(value as Lang.Numeric or Null, decimals as Lang.Number) as Lang.String {
        if (value == null) {
            return "-";
        }
        if (decimals == 1) {
            return value.format("%.1f");
        }
        return value.format("%.0f");
    }
}

class MilTransmitListener extends Communications.ConnectionListener {
    hidden var mView as MilView;

    function initialize(view as MilView) {
        ConnectionListener.initialize();
        mView = view;
    }

    function onComplete() as Void {
        mView.onTransmitComplete();
    }

    function onError() as Void {
        mView.onTransmitError();
    }
}
