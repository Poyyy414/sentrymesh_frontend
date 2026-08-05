import 'package:another_telephony/telephony.dart';

// Sends real SMS directly through the device's own SIM/cellular signal
// (Android's SmsManager, via another_telephony) rather than through any
// backend service. This is deliberate: SMS works over plain cellular
// signal even when the phone has no data/internet, which fits the app's
// tower-first design better than routing through a paid third-party SMS
// gateway. The tradeoff is this can only send from a phone that has the
// app open and signal - it can't have a server proactively text everyone.
class SmsService {
  SmsService();

  final _telephony = Telephony.instance;

  Future<bool> requestPermission() async {
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }

  Future<void> sendSms({required String to, required String message}) async {
    await _telephony.sendSms(to: to, message: message);
  }
}
