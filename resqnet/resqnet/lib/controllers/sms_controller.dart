import 'package:telephony/telephony.dart';
import '../services/sms_service.dart';
import '../utils/constants.dart';

class SmsController {
  void handleIncomingSms(SmsMessage message) {
    final sender = message.address ?? "";
    final body = message.body ?? "";

    if (sender == Constants.trustedNumber) {
      // ✅ Your custom task
      doCustomTask(body);

      // ✅ Send reply
      SmsService().sendSms(sender, "Task completed successfully!");
    }
  }

  void doCustomTask(String body) {
    // Replace this with your real task
    print("Received message: $body");
    print("Doing custom task...");
  }
}
