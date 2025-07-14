import 'package:telephony/telephony.dart';
import '../controllers/sms_controller.dart';

class SmsService {
  final Telephony telephony = Telephony.instance;

  Future<void> initSmsListener() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted == true) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          SmsController().handleIncomingSms(message);
        },
        listenInBackground: true,
      );
    }
  }

  Future<void> sendSms(String to, String message) async {
    await telephony.sendSms(to: to, message: message);
  }
}
