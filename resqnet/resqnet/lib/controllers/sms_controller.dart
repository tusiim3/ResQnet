import 'package:telephony/telephony.dart';
import '../services/sms_service.dart';

class SmsController {
  final Telephony telephony = Telephony.instance;

  void handleIncomingSms(SmsMessage message) {
    final sender = message.address ?? "";
    final body = message.body ?? "";

    // Use the static getter from SmsService
    final String? trustedHardwareContact = SmsService.hardwareContact;

    print("Incoming SMS from: $sender, Body: $body");
    print("Expected trusted hardware contact: $trustedHardwareContact");

    if (trustedHardwareContact != null && sender == trustedHardwareContact) {
      doCustomTask(body);
      // Use the static sendSms method
      SmsService.sendSms(sender, "Task completed successfully!");
    } else {
      print("Unauthorized SMS access attempt from: $sender");
    }
  }

  void doCustomTask(String body) {
    print("Received message for custom task: '$body'");
    print("Performing custom task logic...");
  }
}